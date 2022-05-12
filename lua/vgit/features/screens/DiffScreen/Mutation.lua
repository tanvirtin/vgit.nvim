local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')
local GitObject = require('vgit.git.GitObject')

local Mutation = Object:extend()

function Mutation:constructor()
  return {
    git = Git(),
  }
end

function Mutation:stage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_tracked() then
    return git_object:stage()
  end

  return git_object:stage_hunk(hunk)
end

function Mutation:unstage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_in_remote() then
    return git_object:unstage()
  end

  return git_object:unstage_hunk(hunk)
end

function Mutation:stage_file(filename)
  return self.git:stage_file(filename)
end

function Mutation:unstage_file(filename)
  return self.git:unstage_file(filename)
end

return Mutation
