local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    shape = nil,
    git_object = nil,
    index = 1,
    err = nil,
    data = nil,
    _cache = {},
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
  self.index = 1
  self._cache = {}

  return self
end

function Store:fetch(shape, filename, opts)
  opts = opts or {}

  if not filename or filename == '' then
    return { 'Buffer has no history associated with it' }, nil
  end

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)
  self.err, self.data = self.git_object:logs()

  if self.data and utils.list.is_empty(self.data) then
    return { 'There is no history associated with this buffer' }, nil
  end

  return self.err, self.data
end

function Store:get_all() return self.err, self.data end

function Store:set_index(index)
  self.index = index

  return self
end

function Store:get(index)
  if index then
    self.index = index
  end

  if not self.data or not self.data[self.index] then
    return { 'No data found, check how you are defining store data' }
  end

  return nil, self.data[self.index]
end

function Store:get_diff_dto(index)
  local log_err, log = self:get(index)
  loop.await()

  if log_err then
    return log_err
  end

  local id = log.id
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self._cache[id] then
    return nil, self._cache[id]
  end

  local hunks_err, hunks = self.git_object:remote_hunks(parent_hash, commit_hash)
  loop.await()

  if hunks_err then
    return hunks_err
  end

  local lines_err, lines = self.git_object:lines(commit_hash)
  loop.await()

  if lines_err then
    return lines_err
  end

  local diff = diff_service:generate(hunks, lines, self.shape)

  self._cache[id] = diff

  return nil, diff
end

function Store:get_filename() return nil, self.git_object:get_filename() end

function Store:get_filetype() return nil, self.git_object:get_filetype() end

function Store:get_lnum() return nil, self._cache.lnum end

function Store:set_lnum(lnum)
  self._cache.lnum = lnum

  return self
end

return Store
