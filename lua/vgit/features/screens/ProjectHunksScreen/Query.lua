local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitFile = require('vgit.features.screens.ProjectHunksScreen.GitFile')

local Query = Object:extend()

local git = Git()

function Query:constructor()
  return {
    id = nil,
    err = nil,
    data = nil,
    shape = nil,
    _list_entry_cache = {},
  }
end

function Query:reset()
  self.id = nil
  self.err = nil
  self.data = nil
  self._list_entry_cache = {}

  return self
end

function Query:fetch(shape)
  self:reset()

  if not git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local status_err, files = git:status()

  if status_err then
    return status_err
  end

  if #files == 0 then
    return { 'No files found' }, nil
  end

  local data = {}
  local is_empty = true

  for i = 1, #files do
    local file = files[i]
    local git_file = GitFile(file, shape)
    local hunks_err, hunks = git_file:get_hunks()

    if hunks_err then
      return hunks_err
    end

    if #hunks > 0 then
      is_empty = false
      local entry = data[file.filename]

      if not entry then
        entry = {}
        data[file.filename] = entry
      end

      utils.list.each(hunks, function(hunk, index)
        local id = utils.math.uuid()
        local datum = {
          id = id,
          hunk = hunk,
          mark_index = index,
          git_file = git_file,
          file = git_file.file,
        }

        self._list_entry_cache[id] = datum
        entry[#entry + 1] = datum
      end)
    end
  end

  if is_empty then
    return { 'No files found' }, nil
  end

  self.data = data

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

function Query:get_all()
  return self.err, self.data
end

function Query:get_diff_dto()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  if not data.git_file then
    return {
      'No git file found to get code dto from',
    }, nil
  end

  return data.git_file:get_diff_dto()
end

function Query:get_filename()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  local file = data.file
  local filename = file.filename or ''

  return nil, filename
end

function Query:get_filetype()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  local file = data.file
  local filetype = file.filetype or ''

  return nil, filetype
end

function Query:get_hunk()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  local hunk = data.hunk

  if not hunk then
    return {
      'No hunk found',
    }, nil
  end

  return nil, hunk
end

return Query
