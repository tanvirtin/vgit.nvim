local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git2.repo')
local git_stager = require('vgit.git.git2.stager')
local GitObject = require('vgit.git.GitObject')

local Mutation = Object:extend()

function Mutation:stage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_tracked() then return git_object:stage() end

  return git_object:stage_hunk(hunk)
end

function Mutation:unstage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_tracked() then return git_object:unstage() end

  return git_object:unstage_hunk(hunk)
end

function Mutation:stage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.stage(reponame, filename)
end

function Mutation:unstage_file(filename)
  local reponame = git_repo.discover()
  return git_stager.unstage(reponame, filename)
end

function Mutation:reset_file(filename)
  local reponame = git_repo.discover()

  if git_repo.has(reponame, filename) then return git_repo.reset(reponame, filename) end

  return git_repo.clean(reponame, filename)
end

return Mutation
