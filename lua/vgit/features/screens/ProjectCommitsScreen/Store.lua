local Diff = require('vgit.git.Diff')
local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

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
      commits = {},
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
    commits = {},
  }

  return self
end

function Store:fetch(shape, commits, opts)
  opts = opts or {}

  if self.data and opts.hydrate then
    return nil, self.data
  end

  self:reset()

  if not commits or #commits == 0 then
    return { 'No commits specified' }, nil
  end

  self._cache = {
    lnum = 1,
    list_entry_cache = {},
    commits = {},
  }

  if not self.git:is_inside_git_dir() then
    return { 'Project has no .git folder' }, nil
  end

  self.shape = shape
  local data = {}

  for i = 1, #commits do
    local commit = commits[i]
    -- Get the log associated with the commit
    local log_err, log = self.git:log(commit)
    loop.await_fast_event()

    if log_err then
      return log_err
    end

    -- We will use the parent_hash and the commit_hash inside
    -- the log object to list all the files associated with the log.
    local err, files = self.git:ls_log(log)
    loop.await_fast_event()

    if err then
      return err
    end

    data[commit] = utils.list.map(files, function(file)
      -- Log contains the metadata about parent_hash and commit_hash
      -- File contains the name of the file in that particular working tree.
      -- Using commit_hash, parent_hash and the name of the file we can easily get the lines
      -- and hunks to recreate the diffs by feeding this info into our algorithm.
      local datum = {
        id = utils.math.uuid(),
        log = log,
        file = file,
      }
      self._cache.commits[datum.id] = datum

      return datum
    end)
  end

  self.data = data

  return nil, self.data
end

function Store:get_all()
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

  local datum = self._cache.commits[self.id]

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

  local file = datum.file

  if not file then
    return { 'No file found in item' }, nil
  end

  local id = file.id
  local filename = file.filename
  local log = file.log
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self._cache.commits[id] then
    return nil, self._cache.commits[id]
  end

  local lines_err, lines
  local is_deleted = false

  loop.await_fast_event()
  if not self.git:is_in_remote(filename, commit_hash) then
    is_deleted = true
    lines_err, lines = self.git:show(filename, parent_hash)
  else
    lines_err, lines = self.git:show(filename, commit_hash)
  end
  loop.await_fast_event()

  if lines_err then
    return lines_err
  end

  local hunks_err, hunks
  if is_deleted then
    hunks = self.git:deleted_hunks(lines)
  else
    hunks_err, hunks = self.git:remote_hunks(filename, parent_hash, commit_hash)
  end
  loop.await_fast_event()

  if hunks_err then
    return hunks_err
  end

  local diff
  if is_deleted then
    diff = Diff(hunks):call_deleted(lines, self.shape)
  else
    diff = Diff(hunks):call(lines, self.shape)
  end

  self._cache.commits[id] = diff

  return nil, diff
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

function Store:get_lnum()
  return nil, self._cache.lnum
end

function Store:set_lnum(lnum)
  self._cache.lnum = lnum

  return self
end

function Store:get_list_folds()
  return nil, self._cache.list_folds
end

function Store:set_list_folds(list_folds)
  self._cache.list_folds = list_folds

  return self
end

return Store
