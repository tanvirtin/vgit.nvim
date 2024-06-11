local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Store = Object:extend()

function Store:constructor()
  return {
    shape = nil,
    git_object = nil,
    index = 1,
    err = nil,
    data = nil,
    state = {},
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
  self.index = 1
  self.state = {}
end

function Store:fetch(shape, filename, opts)
  opts = opts or {}

  if not filename or filename == '' then return nil, { 'Buffer has no history associated with it' } end

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)
  self.data, self.err = self.git_object:logs()

  if self.data and utils.list.is_empty(self.data) then
    return nil, { 'There is no history associated with this buffer' }
  end

  return self.data, self.err
end

function Store:get_all()
  return self.data, self.err
end

function Store:set_index(index)
  self.index = index
end

function Store:get(index)
  if index then self.index = index end

  if not self.data or not self.data[self.index] then
    return nil, { 'No data found, check how you are defining store data' }
  end

  return self.data[self.index]
end

function Store:get_diff(index)
  local log, log_err = self:get(index)
  loop.free_textlock()

  if log_err then return nil, log_err end

  local id = log.id
  local parent_hash = log.parent_hash
  local commit_hash = log.commit_hash

  if self.state[id] then return self.state[id] end

  local hunks, hunks_err = self.git_object:list_hunks({
    parent = parent_hash,
    current = commit_hash,
  })
  loop.free_textlock()

  if hunks_err then return nil, hunks_err end

  local lines, lines_err = self.git_object:lines(commit_hash)
  loop.free_textlock()

  if lines_err then return nil, lines_err end

  local diff = Diff():generate(hunks, lines, self.shape)

  self.state[id] = diff

  return diff
end

function Store:get_filename()
  return self.git_object:get_filename()
end

function Store:get_filetype()
  return self.git_object:get_filetype()
end

function Store:get_lnum()
  return self.state.lnum
end

function Store:set_lnum(lnum)
  self.state.lnum = lnum
end

return Store
