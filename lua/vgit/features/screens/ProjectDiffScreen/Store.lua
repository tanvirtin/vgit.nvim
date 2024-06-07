local fs = require('vgit.core.fs')
local Diff = require('vgit.core.Diff')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_show = require('vgit.git.git_show')
local git_repo = require('vgit.git.git_repo')
local git_hunks = require('vgit.git.git_hunks')
local git_status = require('vgit.git.git_status')
local git_conflict = require('vgit.git.git_conflict')

local Store = Object:extend()

function Store:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    state = {
      lnum = 1,
      diffs = {},
      list_folds = {},
      list_entries = {},
    },
  }
end

function Store:partition_status(status_files)
  local changed_files = {}
  local staged_files = {}
  local unmerged_files = {}

  utils.list.each(status_files, function(file)
    if file:is_untracked() then
      local id = utils.math.uuid()
      local data = {
        id = id,
        file = file,
        status = 'unstaged',
      }

      self.state.list_entries[id] = data
      changed_files[#changed_files + 1] = data
    elseif file:is_unmerged() then
      local id = utils.math.uuid()
      local data = {
        id = id,
        file = file,
        status = 'unmerged',
      }

      self.state.list_entries[id] = data
      unmerged_files[#unmerged_files + 1] = data
    else
      if file:is_unstaged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'unstaged',
        }

        self.state.list_entries[id] = data
        changed_files[#changed_files + 1] = data
      end
      if file:is_staged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'staged',
        }

        self.state.list_entries[id] = data
        staged_files[#staged_files + 1] = data
      end
    end
  end)

  return changed_files, staged_files, unmerged_files
end

function Store:get_file_lines(file, status)
  local filename = file.filename

  local reponame = git_repo.discover()
  local lines, err
  if file:has_both('DU') then
    lines, err = git_show.lines(reponame, filename, ':3')
  elseif file:has_both('UD') then
    lines, err = git_show.lines(reponame, filename, ':2')
  elseif file:has('D ') then
    lines, err = git_show.lines(reponame, filename, 'HEAD')
  elseif status == 'staged' or file:has(' D') then
    lines, err = git_show.lines(reponame, filename)
  elseif status == 'unmerged' and git_conflict.has_conflict(reponame, filename) then
    local log, log_err = git_log.get(reponame, 'HEAD')
    if log_err then return nil, log_err end
    lines, err = git_show.lines(reponame, filename, log.commit_hash)
  else
    lines, err = fs.read_file(filename)
  end
  loop.free_textlock()

  return lines, err
end

function Store:get_file_hunks(file, status, lines)
  local filename = file.filename

  local hunks, hunks_err
  local reponame = git_repo.discover()
  if file:has_both('DU') then
    hunks, hunks_err = git_hunks.list(reponame, filename, {
      previous = ':3',
      current = ':1',
      unmerged = true,
    })
  elseif file:has_both('UD') then
    hunks, hunks_err = git_hunks.list(reponame, filename, {
      previous = ':1',
      current = ':2',
      unmerged = true,
    })
  elseif file:has_both('??') then
    hunks = git_hunks.custom(lines, { untracked = true })
  elseif file:has_either('DD') then
    hunks = git_hunks.custom(lines, { deleted = true })
  elseif status == 'staged' then
    hunks, hunks_err = git_hunks.list(reponame, filename, { staged = true })
  elseif status == 'unstaged' then
    hunks, hunks_err = git_hunks.list(reponame, filename)
  elseif status == 'unmerged' then
    if git_conflict.has_conflict(reponame, filename) then
      local head_log, head_log_err = git_log.get(reponame, 'HEAD')
      if head_log_err then return nil, head_log_err end
      local conflict_type, conflict_type_err = git_conflict.status(reponame)
      if conflict_type_err then return nil, conflict_type_err end
      local merge_log, merge_log_err = git_log.get(reponame, conflict_type)
      if merge_log_err then return nil, merge_log_err end
      hunks, hunks_err =
        git_hunks.list(reponame, filename, { parent = head_log.commit_hash, current = merge_log.commit_hash })
    else
      hunks_err = nil
      hunks = {}
    end
  end

  loop.free_textlock()

  return hunks, hunks_err
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self.state = {
    list_entries = {},
    diffs = {},
  }

  return self
end

function Store:fetch(shape, opts)
  opts = opts or {}

  self:reset()

  if not git_repo.exists() then return nil, { 'Project has no .git folder' } end

  loop.free_textlock()
  local reponame = git_repo.discover()
  local status_files, status_files_err = git_status.ls(reponame)
  if status_files_err then return nil, status_files_err end

  local changed_files, staged_files, unmerged_files = self:partition_status(status_files)

  local data = {}
  if #changed_files ~= 0 then data['Changes'] = changed_files end
  if #staged_files ~= 0 then data['Staged Changes'] = staged_files end
  if #unmerged_files ~= 0 then data['Merge Changes'] = unmerged_files end

  self.shape = shape
  self.data = data

  return self.data, nil
end

function Store:get_all()
  return self.data, self.err
end

function Store:set_id(id)
  self.id = id
  return self
end

function Store:get(id)
  if id then self.id = id end

  local datum = self.state.list_entries[self.id]
  if not datum then return nil, { 'Item not found' } end

  return datum, nil
end

function Store:get_diff()
  local datum, err = self:get()
  if err then return nil, err end

  local id = datum.id
  local file = datum.file
  local status = datum.status

  if not file then return nil, { 'No file found in item' } end

  local cache_key = string.format('%s-%s-%s', id, status, file.id)
  if self.state.diffs[cache_key] then return self.state.diffs[cache_key], nil end

  local lines, lines_err = self:get_file_lines(file, status)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_file_hunks(file, status, lines)
  if hunks_err then return nil, hunks_err end

  local is_deleted = not (file:has_both('DU') or file:has_both('UD')) and file:has_either('DD')
  local diff = Diff():generate(hunks, lines, self.shape, { is_deleted = is_deleted })

  self.state.diffs[cache_key] = diff

  return self.state.diffs[cache_key], nil
end

function Store:get_filename()
  local datum, err = self:get()
  if err then return nil, err end

  return datum.file.filename, nil
end

function Store:get_filetype()
  local datum, err = self:get()
  if err then return nil, err end

  return datum.file.filetype, nil
end

function Store:get_lnum()
  return self.state.lnum, nil
end

function Store:set_lnum(lnum)
  self.state.lnum = lnum
  return self
end

function Store:get_list_folds()
  return self.state.list_folds
end

function Store:set_list_folds(list_folds)
  self.state.list_folds = list_folds
  return self
end

return Store
