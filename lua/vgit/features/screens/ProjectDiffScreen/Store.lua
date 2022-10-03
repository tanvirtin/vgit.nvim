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
    else
      if not file:has_conflict() and file:is_unstaged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'unstaged',
        }

        self._cache.list_entries[id] = data
        changed_files[#changed_files + 1] = data
      end
      if not file:has_conflict() and file:is_staged() then
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

  return changed_files, staged_files
end

function Store:get_file_lines(file, status)
  local filename = file.filename
  local file_status = file.status
  local lines_err, lines

  if file_status:has('D ') then
    lines_err, lines = self.git:show(filename, 'HEAD')
  elseif status == 'staged' or file_status:has(' D') then
    lines_err, lines = self.git:show(self.git:tracked_filename(filename))
  else
    lines_err, lines = fs.read_file(filename)
  end
  loop.await()

  return lines_err, lines
end

function Store:get_file_hunks(file, status, lines)
  local filename = file.filename
  local file_status = file.status
  local hunks_err, hunks

  if file_status:has_both('??') then
    hunks = self.git:untracked_hunks(lines)
  elseif file_status:has_either('DD') then
    hunks = self.git:deleted_hunks(lines)
  elseif status == 'staged' then
    hunks_err, hunks = self.git:staged_hunks(filename)
  elseif status == 'unstaged' then
    hunks_err, hunks = self.git:index_hunks(filename)
  end

  loop.await()

  return hunks_err, hunks
end

function Store:get_file_diff(file, lines, hunks)
  local status = file.status

  local diff = diff_service:generate(hunks, lines, self.shape, {
    is_deleted = status:has_either('DD'),
  })

  return diff
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self._cache = {
    list_folds = {},
    list_entries = {},
    diff_dtos = {},
    lnum = 1,
  }

  return self
end

function Store:fetch(shape, opts)
  opts = opts or {}

  if self.data and opts.hydrate and not opts.partial_hydrate then
    return nil, self.data
  end

  self:reset()

  if not opts.partial_hydrate then
    self._cache = {
      list_entries = {},
      diff_dtos = {},
    }
  end

  if not self.git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local status_files_err, status_files = self.git:status()
  loop.await()

  if status_files_err then
    return status_files_err, nil
  end

  local changed_files, staged_files = self:partition_status(status_files)

  local data = {
    changes = changed_files,
    staged = staged_files,
  }

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

  self._cache.diff_dtos[cache_key] = self:get_file_diff(file, lines, hunks)

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
