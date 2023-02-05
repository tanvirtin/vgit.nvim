local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')
local DiffDTO = require('vgit.services.diff.DiffDTO')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_object = nil,
    _cache = {
      lines = nil,
      diff_dto = nil,
    },
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
  self._cache = {
    lines = nil,
    diff_dto = nil,
  }

  return self
end

function Store:fetch(filename, lines)
  if not filename or filename == '' then
    return { 'Buffer has no blame associated with it' }, nil
  end

  self:reset()

  self.git_object = GitObject(filename)

  loop.free_textlock()
  self.err, self.data = self.git_object:blames()
  loop.free_textlock()

  self._cache.lines = lines

  return self.err, self.data
end

function Store:get_blames() return self.err, self.data end

function Store:get_diff_dto()
  if self._cache.diff_dto then
    return nil, self._cache.diff_dto
  end

  self._cache.diff_dto = DiffDTO({ lines = self._cache.lines })

  return nil, self._cache.diff_dto
end

function Store:get_filename() return nil, self.git_object:get_filename() end

function Store:get_filetype() return nil, self.git_object:get_filetype() end

return Store
