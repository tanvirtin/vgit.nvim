local fs = require('vgit.core.fs')
local Diff = require('vgit.git.Diff')
local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Query = Object:extend()

local git = Git()

function Query:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    _list_entry_cache = {},
    _diff_dto_cache = {},
  }
end

function Query:partition_status(status_files)
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

      self._list_entry_cache[id] = data
      changed_files[#changed_files + 1] = data
    else
      if file:is_unstaged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'unstaged',
        }

        self._list_entry_cache[id] = data
        changed_files[#changed_files + 1] = data
      end
      if file:is_staged() then
        local id = utils.math.uuid()
        local data = {
          id = id,
          file = file,
          status = 'staged',
        }

        self._list_entry_cache[id] = data
        staged_files[#staged_files + 1] = data
      end
    end
  end)

  return changed_files, staged_files
end

function Query:get_file_lines(file, status)
  local filename = file.filename
  local file_status = file.status
  local lines_err, lines

  if file_status:has('D ') then
    lines_err, lines = git:show(filename, 'HEAD')
  elseif status == 'staged' or file_status:has(' D') then
    lines_err, lines = git:show(git:tracked_filename(filename))
  else
    lines_err, lines = fs.read_file(filename)
  end
  loop.await_fast_event()

  return lines_err, lines
end

function Query:get_file_hunks(file, status, lines)
  local filename = file.filename
  local file_status = file.status
  local hunks_err, hunks

  if file_status:has_both('??') then
    hunks = git:untracked_hunks(lines)
  elseif file_status:has_either('DD') then
    hunks = git:deleted_hunks(lines)
  elseif status == 'staged' then
    hunks_err, hunks = git:staged_hunks(filename)
  elseif status == 'unstaged' then
    hunks_err, hunks = git:index_hunks(filename)
  end

  loop.await_fast_event()

  return hunks_err, hunks
end

function Query:get_file_diff(file, lines, hunks)
  local shape = self.shape
  local status = file.status
  local diff

  if status:has_either('DD') then
    diff = shape == 'unified' and Diff(hunks):deleted_unified(lines)
      or Diff(hunks):deleted_split(lines)
  else
    diff = shape == 'unified' and Diff(hunks):unified(lines)
      or Diff(hunks):split(lines)
  end

  return diff
end

function Query:reset()
  self._list_entry_cache = {}
  self._diff_dto_cache = {}
  self.id = nil
  self.err = nil
  self.data = nil

  return self
end

function Query:fetch(shape, preserve_caching)
  self:reset()

  if not preserve_caching then
    self._list_entry_cache = {}
    self._diff_dto_cache = {}
  end

  if not git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local status_files_err, status_files = git:status()
  loop.await_fast_event()

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

function Query:get_all()
  return self.err, self.data
end

function Query:set_id(id)
  self.id = id

  return self
end

function Query:get(id)
  if id then
    self.id = id
  end

  local datum = self._list_entry_cache[self.id]

  if not datum then
    return { 'Item not found' }, nil
  end

  return nil, datum
end

function Query:get_diff_dto()
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

  if self._diff_dto_cache[cache_key] then
    return nil, self._diff_dto_cache[cache_key]
  end

  local lines_err, lines = self:get_file_lines(file, status)

  if lines_err then
    return lines_err, nil
  end

  local hunks_err, hunks = self:get_file_hunks(file, status, lines)

  if hunks_err then
    return hunks_err
  end

  self._diff_dto_cache[cache_key] = self:get_file_diff(file, lines, hunks)

  return nil, self._diff_dto_cache[cache_key]
end

function Query:get_filename()
  local err, datum = self:get()

  if err then
    return err
  end

  return nil, datum.file.filename
end

function Query:get_filetype()
  local err, datum = self:get()

  if err then
    return err
  end

  return nil, datum.file.filetype
end

return Query
