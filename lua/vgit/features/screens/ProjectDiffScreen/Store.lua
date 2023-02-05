local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    git = Git(),
    _cache = {
      list_folds = {},
      list_entries = {},
      diff_dtos = {},
      lnum = 1,
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

      self._cache.list_entries[id] = data
      changed_files[#changed_files + 1] = data
    elseif file:is_unmerged() then
      local id = utils.math.uuid()
      local data = {
        id = id,
        file = file,
        status = 'unmerged',
      }

      self._cache.list_entries[id] = data
      unmerged_files[#unmerged_files + 1] = data
    else
      if file:is_unstaged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'unstaged',
        }

        self._cache.list_entries[id] = data
        changed_files[#changed_files + 1] = data
      end
      if file:is_staged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'staged',
        }

        self._cache.list_entries[id] = data
        staged_files[#staged_files + 1] = data
      end
    end
  end)

  return changed_files, staged_files, unmerged_files
end

function Store:get_file_lines(file, status)
  local filename = file.filename
  local file_status = file.status
  local err, lines

  if file_status:has_both('DU') then
    err, lines = self.git:show(filename, ':3')
  elseif file_status:has_both('UD') then
    err, lines = self.git:show(filename, ':2')
  elseif file_status:has('D ') then
    err, lines = self.git:show(filename, 'HEAD')
  elseif status == 'staged' or file_status:has(' D') then
    err, lines = self.git:show(self.git:tracked_filename(filename))
  else
    err, lines = fs.read_file(filename)
  end
  loop.free_textlock()

  return err, lines
end

function Store:get_file_hunks(file, status, lines)
  local filename = file.filename
  local file_status = file.status
  local hunks_err, hunks

  if file_status:has_both('DU') then
    hunks_err, hunks = self.git:unmerged_hunks(filename, ':3', ':1')
  elseif file_status:has_both('UD') then
    hunks_err, hunks = self.git:unmerged_hunks(filename, ':1', ':2')
  elseif file_status:has_both('??') then
    hunks = self.git:untracked_hunks(lines)
  elseif file_status:has_either('DD') then
    hunks = self.git:deleted_hunks(lines)
  elseif status == 'staged' then
    hunks_err, hunks = self.git:staged_hunks(filename)
  elseif status == 'unstaged' then
    hunks_err, hunks = self.git:index_hunks(filename)
  elseif status == 'unmerged' then
    hunks_err = nil
    hunks = {}
  end

  loop.free_textlock()

  return hunks_err, hunks
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self._cache = {
    list_entries = {},
    diff_dtos = {},
  }

  return self
end

function Store:fetch(shape, opts)
  opts = opts or {}

  self:reset()

  if not self.git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local status_files_err, status_files = self.git:status()
  loop.free_textlock()

  if status_files_err then
    return status_files_err, nil
  end

  local changed_files, staged_files, unmerged_files = self:partition_status(status_files)

  local data = {}

  if #changed_files ~= 0 then
    data['Changes'] = changed_files
  end

  if #staged_files ~= 0 then
    data['Staged Changes'] = staged_files
  end

  if #unmerged_files ~= 0 then
    data['Merge Changes'] = unmerged_files
  end

  self.shape = shape
  self.data = data

  return nil, self.data
end

function Store:get_all() return self.err, self.data end

function Store:set_id(id)
  self.id = id

  return self
end

function Store:get(id)
  if id then
    self.id = id
  end

  local datum = self._cache.list_entries[self.id]

  if not datum then
    return { 'Item not found' }, nil
  end

  return nil, datum
end

function Store:get_diff_dto()
  local err, datum = self:get()

  if err then
    return err
  end

  local id = datum.id
  local file = datum.file
  local status = datum.status

  if not file then
    return { 'No file found in item' }, nil
  end

  local cache_key = string.format('%s-%s-%s', id, status, file.id)

  if self._cache.diff_dtos[cache_key] then
    return nil, self._cache.diff_dtos[cache_key]
  end

  local lines_err, lines = self:get_file_lines(file, status)

  if lines_err then
    return lines_err, nil
  end

  local hunks_err, hunks = self:get_file_hunks(file, status, lines)

  if hunks_err then
    return hunks_err
  end

  local file_status = file.status
  local is_deleted = not (file_status:has_both('DU') or file_status:has_both('UD')) and file_status:has_either('DD')
  local diff_dto = diff_service:generate(hunks, lines, self.shape, { is_deleted = is_deleted })

  self._cache.diff_dtos[cache_key] = diff_dto

  return nil, self._cache.diff_dtos[cache_key]
end

function Store:get_filename()
  local err, datum = self:get()

  if err then
    return err
  end

  return nil, datum.file.filename
end

function Store:get_filetype()
  local err, datum = self:get()

  if err then
    return err
  end

  return nil, datum.file.filetype
end

function Store:get_lnum() return nil, self._cache.lnum end

function Store:set_lnum(lnum)
  self._cache.lnum = lnum

  return self
end

function Store:get_list_folds() return nil, self._cache.list_folds end

function Store:set_list_folds(list_folds)
  self._cache.list_folds = list_folds

  return self
end

return Store
