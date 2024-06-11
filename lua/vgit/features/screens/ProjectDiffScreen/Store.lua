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

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self.state = {
    diffs = {},
    list_entries = {},
  }
end

function Store:partition_status(statuses)
  local changed_files = {}
  local staged_files = {}
  local unmerged_files = {}

  utils.list.each(statuses, function(status)
    if status:is_unmerged() then
      local id = utils.math.uuid()
      local data = { id = id, file = status, type = 'unmerged' }
      self.state.list_entries[id] = data
      table.insert(unmerged_files, data)
      -- If something is unmerged it cannot be untracked or staged
      return
    end

    if status:is_staged() then
      local id = utils.math.uuid()
      local data = { id = id, file = status, type = 'staged' }
      self.state.list_entries[id] = data
      table.insert(staged_files, data)
    end

    if status:is_unstaged() then
      local id = utils.math.uuid()
      local data = { id = id, file = status, type = 'unstaged' }
      self.state.list_entries[id] = data
      table.insert(changed_files, data)
    end
  end)

  return changed_files, staged_files, unmerged_files
end

function Store:fetch(shape, opts)
  opts = opts or {}

  self:reset()

  if not git_repo.exists() then return nil, { 'Project has no .git folder' } end

  loop.free_textlock()
  local reponame = git_repo.discover()
  local statuses, statuses_err = git_status.ls(reponame)
  if statuses_err then return nil, statuses_err end

  local changed_files, staged_files, unmerged_files = self:partition_status(statuses)

  local data = {}
  if #changed_files ~= 0 then data['Changes'] = changed_files end
  if #staged_files ~= 0 then data['Staged Changes'] = staged_files end
  if #unmerged_files ~= 0 then data['Merge Changes'] = unmerged_files end

  self.shape = shape
  self.data = data

  return self.data
end

function Store:get(id)
  if id then self.id = id end
  return self.state.list_entries[self.id]
end

function Store:get_all()
  return self.data, self.err
end

function Store:set_id(id)
  self.id = id
end

function Store:get_filename()
  local entry, err = self:get()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.file.filename
end

function Store:get_filetype()
  local entry, err = self:get()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  return entry.file.filetype
end

function Store:get_lnum()
  return self.state.lnum
end

function Store:set_lnum(lnum)
  self.state.lnum = lnum
end

function Store:get_list_folds()
  return self.state.list_folds
end

function Store:set_list_folds(list_folds)
  self.state.list_folds = list_folds
end

function Store:get_file_lines(status, type)
  local filename = status.filename
  local reponame = git_repo.discover()

  if type == 'unmerged' then
    if status:has_both('UD') then return git_show.lines(reponame, filename, ':2') end
    if status:has_both('DU') then return git_show.lines(reponame, filename, ':3') end
    local log, log_err = git_log.get(reponame, 'HEAD')
    if log_err then return nil, log_err end
    if not log then return nil, { 'failed to find log at HEAD' } end
    return git_show.lines(reponame, filename, log.commit_hash)
  end
  if status:has('D ') then return git_show.lines(reponame, filename, 'HEAD') end
  if type == 'staged' or status:has(' D') then return git_show.lines(reponame, filename) end

  return fs.read_file(filename)
end

function Store:get_file_hunks(status, type, lines)
  local filename = status.filename
  local reponame = git_repo.discover()

  if type == 'unmerged' then
    if status:has_both('UD') then return git_hunks.custom(lines, { deleted = true }) end
    if status:has_both('DU') then return git_hunks.custom(lines, { untracked = true }) end
    if status:has_either('DD') then return git_hunks.custom(lines, { deleted = true }) end
    local head_log, head_log_err = git_log.get(reponame, 'HEAD')
    if head_log_err then return nil, head_log_err end
    if not head_log then return nil, { 'failed to find head log' } end
    local conflict_type, conflict_type_err = git_conflict.status(reponame)
    if conflict_type_err then return nil, conflict_type_err end
    local merge_log, merge_log_err = git_log.get(reponame, conflict_type)
    if not merge_log then return nil, { 'failed to find merge log' } end
    if merge_log_err then return nil, merge_log_err end
    return git_hunks.list(reponame, filename, { parent = head_log.commit_hash, current = merge_log.commit_hash })
  end
  if status:has_both('??') then return git_hunks.custom(lines, { untracked = true }) end
  if type == 'staged' then return git_hunks.list(reponame, filename, { staged = true }) end
  if type == 'unstaged' then return git_hunks.list(reponame, filename) end

  return {}
end

function Store:get_diff()
  local entry, err = self:get()
  if err then return nil, err end
  if not entry then return nil, { 'entry not found' } end

  local id = entry.id
  local type = entry.type
  local status = entry.file
  if not status then return nil, { 'No file found in entry' } end

  local cache_key = string.format('%s-%s-%s', id, type, status.id)
  if self.state.diffs[cache_key] then return self.state.diffs[cache_key] end

  local lines, lines_err = self:get_file_lines(status, type)
  if lines_err then return nil, lines_err end

  local hunks, hunks_err = self:get_file_hunks(status, type, lines)
  if hunks_err then return nil, hunks_err end

  loop.free_textlock()
  local diff = Diff():generate(hunks, lines, self.shape, { is_deleted = status:has_either('*D') })
  self.state.diffs[cache_key] = diff

  return diff
end

return Store
