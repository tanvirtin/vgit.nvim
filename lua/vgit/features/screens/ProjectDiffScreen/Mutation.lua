local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

local Mutation = Object:extend()

function Mutation:constructor()
  return {
    git = Git(),
  }
end

function Mutation:stage_file(filename)
  return self.git:stage_file(filename)
end

function Mutation:unstage_file(filename)
  return self.git:unstage_file(filename)
end

function Mutation:stage_all()
  return self.git:stage()
end

function Mutation:unstage_all()
  return self.git:unstage()
end

function Mutation:reset_all()
  return self.git:reset_all()
end

function Mutation:clean_all()
  return self.git:clean_all()
end

return Mutation
