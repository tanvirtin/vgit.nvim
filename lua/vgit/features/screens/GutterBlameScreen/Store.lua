local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local DiffDTO = require('vgit.git.DiffDTO')
local GitObject = require('vgit.git.GitObject')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_object = nil,
    _cache = nil,
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
  self._cache = nil

  return self
end

function Store:fetch(filename, opts)
  opts = opts or {}

  if self.data and opts.hydrate then
    return nil, self.data
  end

  self:reset()

  self.git_object = GitObject(filename)

  loop.await_fast_event()
  self.err, self.data = self.git_object:blames()
  loop.await_fast_event()

  return self.err, self.data
end

function Store:get_blames()
  return self.err, self.data
end

function Store:get_diff_dto()
  if self._cache then
    return nil, self._cache
  end

  loop.await_fast_event()
  local err, lines = self.git_object:lines()
  loop.await_fast_event()

  if err then
    return err
  end

  self._cache = DiffDTO({
    lines = lines,
  })

  return nil, self._cache
end

function Store:get_filename()
  return nil, self.git_object:get_filename()
end

function Store:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Store
