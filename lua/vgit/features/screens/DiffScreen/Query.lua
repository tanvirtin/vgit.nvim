local Diff = require('vgit.git.Diff')
local fs = require('vgit.core.fs')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Query = Object:extend()

function Query:constructor()
  return {
    err = nil,
    data = nil,
    shape = nil,
    git_object = nil,
    _diff_dto_cache = {},
  }
end

function Query:reset()
  self.err = nil
  self.data = nil
  self._diff_dto_cache = {}

  return self
end

function Query:fetch(shape, filename, opts)
  opts = opts or {}

  self:reset()

  self.shape = shape
  self.git_object = GitObject(filename)
  local lines_err, lines = fs.read_file(filename)

  if lines_err then
    self.err = lines_err

    return lines_err
  end

  self._diff_dto_cache['lines'] = lines

  if opts.is_staged then
    self.err, self.data = self.git_object:staged_hunks(lines)
  else
    self.err, self.data = self.git_object:live_hunks(lines)
  end

  return self.err, self.data
end

function Query:get()
  return nil, self.data
end

function Query:get_diff_dto()
  local data_err, data = self:get()

  if data_err then
    return data_err
  end

  if self._diff_dto_cache['diff_dto'] then
    return nil, self._diff_dto_cache['diff_dto']
  end

  self._diff_dto_cache['diff_dto'] = Diff(data):call(
    self._diff_dto_cache['lines'],
    self.shape
  )

  return nil, self._diff_dto_cache['diff_dto']
end

function Query:get_filename()
  return nil, self.git_object:get_filename()
end

function Query:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Query
