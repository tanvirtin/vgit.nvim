local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_service = require('vgit.services.git')
local DiffDTO = require('vgit.services.diff.DiffDTO')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_blob = nil,
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

  self.git_blob = git_service:get_blob(filename)

  loop.await()
  self.err, self.data = self.git_blob:blame_lines()
  loop.await()

  return self.err, self.data
end

function Store:get_blames() return self.err, self.data end

function Store:get_diff_dto()
  if self._cache then
    return nil, self._cache
  end

  loop.await()
  local err, lines = self.git_blob:get_lines()
  loop.await()

  if err then
    return err
  end

  self._cache = DiffDTO({
    lines = lines,
  })

  return nil, self._cache
end

function Store:get_filename() return nil, self.git_blob:get_filename() end

function Store:get_filetype() return nil, self.git_blob:get_filetype() end

return Store
