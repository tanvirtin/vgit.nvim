local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local DiffDTO = require('vgit.git.DiffDTO')
local GitObject = require('vgit.git.GitObject')

local Query = Object:extend()

function Query:constructor()
  return {
    err = nil,
    data = nil,
    git_object = nil,
    _diff_dto_cache = nil,
  }
end

function Query:reset()
  self.err = nil
  self.data = nil

  return self
end

function Query:fetch(filename)
  self:reset()

  self.git_object = GitObject(filename)

  loop.await_fast_event()
  self.err, self.data = self.git_object:blames()
  loop.await_fast_event()

  return self.err, self.data
end

function Query:get_blames()
  return self.err, self.data
end

function Query:get_diff_dto()
  if self._diff_dto_cache then
    return nil, self._diff_dto_cache
  end

  loop.await_fast_event()
  local err, lines = self.git_object:lines()
  loop.await_fast_event()

  if err then
    return err
  end

  self._diff_dto_cache = DiffDTO({
    lines = lines,
  })

  return nil, self._diff_dto_cache
end

function Query:get_filename()
  return nil, self.git_object:get_filename()
end

function Query:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Query
