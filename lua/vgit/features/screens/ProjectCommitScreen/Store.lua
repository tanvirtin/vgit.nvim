local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
    git = Git(),
  }
end

function Store:reset()
  self.err = nil
  self.data = nil

  return self
end

function Store:fetch(opts)
  opts = opts or {}

  self:reset()

  self.err, self.data = self.git:get_commit()

  return self.err, self.data
end

function Store:get_lines()
  if self.err then
    return self.err
  end

  return nil, utils.list.concat({ '' }, utils.list.map(self.data, function(line) return '# ' .. line end))
end

return Store
