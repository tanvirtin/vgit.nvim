local loop = require('vgit.core.loop')
local Diff = require('vgit.core.Diff')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git_object = nil,
    state = {
      lines = nil,
      diff = nil,
    },
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
  self.state = {
    lines = nil,
    diff = nil,
  }

  return self
end

function Store:fetch(filename, lines)
  if not filename or filename == '' then return { 'Buffer has no blame associated with it' }, nil end

  self:reset()

  self.git_object = GitObject(filename)

  loop.free_textlock()
  self.data, self.err = self.git_object:blames()
  loop.free_textlock()

  self.state.lines = lines

  return self.err, self.data
end

function Store:get_blames()
  return self.err, self.data
end

function Store:get_diff()
  if self.state.diff then return nil, self.state.diff end

  self.state.diff = Diff({ lines = self.state.lines })

  return nil, self.state.diff
end

function Store:get_filename()
  return nil, self.git_object:get_filename()
end

function Store:get_filetype()
  return nil, self.git_object:get_filetype()
end

return Store
