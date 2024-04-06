local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')
local diff_service = require('vgit.services.diff')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    shape = nil,
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

function Store:fetch(shape, filename, opts)
  opts = opts or {}

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)

  local lines_err, lines

  if opts.is_staged then
    lines, lines_err = self.git_object:lines()
  else
    lines, lines_err = fs.read_file(filename)
  end

  if lines_err then
    self.err = lines_err

    return lines_err
  end

  self._cache.lines = lines

  if opts.is_staged then
    self.data, self.err = self.git_object:staged_hunks()
  else
    self.err, self.data = self.git_object:live_hunks(lines)
  end

  return self.err, self.data
end

function Store:get_diff_dto()
  if self._cache.diff_dto then
    return nil, self._cache.diff_dto
  end

  self._cache.diff_dto = diff_service:generate(self.data, self._cache.lines, self.shape)

  return nil, self._cache.diff_dto
end

function Store:get_filename() return nil, self.git_object:get_filename() end

function Store:get_filetype() return nil, self.git_object:get_filetype() end

return Store
