local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitFile = require('vgit.features.screens.ProjectHunksScreen.GitFile')

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

  if self.data and opts.hydrate then
    return nil, self.data
  end

  self:reset()

  if not self.git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  local status_err, files = self.git:status()

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
    local hunks_err, hunks

    if opts.is_staged then
      hunks_err, hunks = git_file:get_staged_hunks()
    else
      hunks_err, hunks = git_file:get_hunks()
    end

    if hunks_err then
      return hunks_err
    end

    if hunks and #hunks > 0 then
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

        self._cache.list_entry_cache[id] = datum
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

function Store:set_id(id)
  self.id = id

  return self
end

function Store:get(id)
  if id then
    self.id = id
  end

  local datum = self._cache.list_entry_cache[self.id]

  if not datum then
    return { 'Item not found' }, nil
  end

  return nil, datum
end

function Store:get_all() return self.err, self.data end

function Store:get_diff_dto()
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

function Store:get_filename()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  local file = data.file
  local filename = file.filename or ''

  return nil, filename
end

function Store:get_filetype()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  local file = data.file
  local filetype = file.filetype or ''

  return nil, filetype
end

function Store:get_hunk()
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
