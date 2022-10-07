local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_service = require('vgit.services.git')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_blob = nil,
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

  if self.data and opts.hydrate then
    return nil, self.data
  end

  self:reset()

  self.git_blob = git_service:get_blob(filename)

  loop.await()
  self.err, self.data = self.git_blob:blame_line(lnum)
  loop.await()

  return self.err, self.data
end

function Store:get_blame() return self.err, self.data end

return Store
