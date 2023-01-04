local fs = require('vgit.core.fs')
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
      lnum = 1,
      list_entry_cache = {},
    },
  }
end

function Store:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self._cache = {
    lnum = 1,
    list_entry_cache = {},
  }

  return self
end

function Store:fetch(shape, opts)
  opts = opts or {}

  self:reset()

  if not self.git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local files_err, files = self.git:status()

  if files_err then
    return files_err
  end

  if #files == 0 then
    return { 'No files found' }, nil
  end

  local data = {}
  local is_empty = true

  for i = 1, #files do
    local file = files[i]
    local status = file.status

    local lines_err, lines = self:get_lines(file)

    if lines_err then
      return lines_err, nil
    end

    local hunks_err, hunks = self:get_hunks(file, lines, opts.is_staged)

    if hunks_err then
      return hunks_err
    end

    if hunks and #hunks > 0 then
      is_empty = false

      local entry = data[file.filename] or {}
      data[file.filename] = entry

      local diff_dto = diff_service:generate(hunks, lines, shape, {
        is_deleted = status and status:has_either('DD'),
      })

      utils.list.each(hunks, function(hunk, index)
        local id = utils.math.uuid()
        local data = {
          id = id,
          hunk = hunk,
          file = file,
          mark_index = index,
          diff_dto = diff_dto,
        }

        self._cache.list_entry_cache[id] = data
        entry[#entry + 1] = data
      end)
    end
  end

  if is_empty then
    return { 'No files found' }, nil
  end

  self.data = data

  return self.err, self.data
end

function Store:set_id(id)
  self.id = id

  return self
end

function Store:get_data(id)
  if id then
    self.id = id
  end

  local data = self._cache.list_entry_cache[self.id]

  if not data then
    return { 'Item not found' }, nil
  end

  return nil, data
end

function Store:get_all() return self.err, self.data end

function Store:get_diff_dto()
  local data_err, data = self:get_data()

  if data_err then
    return data_err
  end

  if not data.diff_dto then
    return { 'No git file found to get code dto from' }, nil
  end

  return nil, data.diff_dto
end

function Store:get_filename()
  local data_err, data = self:get_data()

  if data_err then
    return data_err
  end

  local file = data.file
  local filename = file.filename or ''

  return nil, filename
end

function Store:get_filetype()
  local data_err, data = self:get_data()

  if data_err then
    return data_err
  end

  local file = data.file
  local filetype = file.filetype or ''

  return nil, filetype
end

function Store:get_lines(file)
  local filename = file.filename
  local status = file.status

  local lines_err, lines

  if status then
    if status:has('D ') then
      lines_err, lines = self.git:show(filename, 'HEAD')
    elseif status:has(' D') then
      lines_err, lines = self.git:show(self.git:tracked_filename(filename))
    else
      lines_err, lines = fs.read_file(filename)
    end
  else
    lines_err, lines = fs.read_file(filename)
  end

  return lines_err, lines
end

function Store:get_hunks(file, lines, is_staged)
  local filename = file.filename
  local status = file.status
  local log = file.log
  local hunks_err, hunks

  if is_staged then
    if file:is_staged() then
      return self.git:staged_hunks(filename)
    end

    return nil, nil
  end

  if status then
    if status:has_both('??') then
      hunks = self.git:untracked_hunks(lines)
    elseif status:has_either('DD') then
      hunks = self.git:deleted_hunks(lines)
    else
      return self.git:index_hunks(filename)
    end
  elseif log then
    hunks_err, hunks = self.git:remote_hunks(filename, log.parent_hash, log.commit_hash)
  else
    hunks_err, hunks = self.git:index_hunks(filename)
  end

  return hunks_err, hunks
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
