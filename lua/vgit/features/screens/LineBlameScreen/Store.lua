local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_object = nil,
    _diff_dto_cache = nil,
  }
end

function Store:reset()
  self.err = nil
  self.data = nil

  return self
end

function Store:fetch(filename, lnum, opts)
  opts = opts or {}

  self:reset()

  self.git_object = GitObject(filename)

  loop.await()
  self.err, self.data = self.git_object:blame_line(lnum)
  loop.await()

  return self.err, self.data
end

function Store:get_blame() return self.err, self.data end

return Store
