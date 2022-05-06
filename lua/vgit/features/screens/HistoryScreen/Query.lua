local Diff = require('vgit.git.Diff')
local utils = require('vgit.core.utils')
local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Query = Object:extend()

function Query:constructor()
  return {
    shape = nil,
    git_object = nil,
    index = 1,
    err = nil,
    data = nil,
    _cache = {},
  }
end

function Query:reset()
  self.err = nil
  self.data = nil
  self.index = 1
  self._cache = {}

  return self
end

function Query:fetch(shape, filename)
  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)
  self.err, self.data = self.git_object:logs()

  if self.data and utils.list.is_empty(self.data) then
    return { 'There is no history associated with this buffer' }, nil
  end

  return self.err, self.data
end

function Query:get_all()
  return self.err, self.data
end

function Query:set_index(index)
  self.index = index

  return self
end

function Query:get(index)
  if index then
    self.index = index
  end

  if not self.data or not self.data[self.index] then
    return { 'No data found, check how you are defining query data' }
  end

  return nil, self.data[self.index]
end

function Query:get_diff_dto(index)
  local log_err, log = self:get(index)
  loop.await_fast_event()

  if log_err then
    return log_err
  end

  local id = log.id
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self._cache[id] then
    return nil, self._cache[id]
  end

  local hunks_err, hunks = self.git_object:remote_hunks(
    parent_hash,
    commit_hash
  )
  loop.await_fast_event()

  if hunks_err then
    return hunks_err
  end

  local lines_err, lines = self.git_object:lines(commit_hash)
  loop.await_fast_event()

  if lines_err then
    return lines_err
  end

  local diff
  if self.shape == 'unified' then
    diff = Diff(hunks):unified(lines)
  else
    diff = Diff(hunks):split(lines)
  end

  self._cache[id] = diff

  return nil, diff
end

function Query:get_filename()
  return nil, self.git_object:get_filename()
end

function Query:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Query
