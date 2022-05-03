local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

local Mutation = Object:extend()

local git = Git()

function Mutation:stage_file(filename)
  return git:stage_file(filename)
end

function Mutation:unstage_file(filename)
  return git:unstage_file(filename)
end

function Mutation:stage_all()
  return git:stage()
end

function Mutation:unstage_all()
  return git:unstage()
end

function Mutation:reset_all()
  return git:reset_all()
end

function Mutation:clean_all()
  return git:clean_all()
end

return Mutation
