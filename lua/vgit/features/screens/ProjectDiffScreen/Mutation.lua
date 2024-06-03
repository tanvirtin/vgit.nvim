local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local GitObject = require('vgit.git.GitObject')
local git_stager = require('vgit.git.git_stager')

local Mutation = Object:extend()

function Mutation:stage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_tracked() then return git_object:stage() end

  local file, err = git_object:status()
  if err then return err end

  local file_status = file.status

  if file_status:has('D ') or file_status:has(' D') then return git_object:stage() end

  return git_object:stage_hunk(hunk)
end

function Mutation:unstage_hunk(filename, hunk)
  local git_object = GitObject(filename)

  if not git_object:is_tracked() then return git_object:unstage() end

  local file, err = git_object:status()
  if err then return err end

  local file_status = file.status

  if file_status:has('D ') or file_status:has(' D') then return self.git:unstage_file(filename) end

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

function Mutation:stage_all()
  local reponame = git_repo.discover()
  return git_stager.stage(reponame)
end

function Mutation:unstage_all()
  local reponame = git_repo.discover()
  return git_stager.unstage(reponame)
end

function Mutation:reset_all()
  local reponame = git_repo.discover()
  local _, reset_err = git_repo.reset(reponame)
  if reset_err then return reset_err end

  return git_repo.clean(reponame)
end

return Mutation
