local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
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

function Query:fetch(filename, lnum)
  self:reset()

  self.git_object = GitObject(filename)

  loop.await_fast_event()
  self.err, self.data = self.git_object:blame_line(lnum)
  loop.await_fast_event()

  return self.err, self.data
end

function Query:get_blame()
  return self.err, self.data
end

return Query
