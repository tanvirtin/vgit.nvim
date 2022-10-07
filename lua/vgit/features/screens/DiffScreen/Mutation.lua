local Object = require('vgit.core.Object')
local git_service = require('vgit.services.git')

local Mutation = Object:extend()

function Mutation:constructor()
  return {
    git_repository = git_service:get_repository(),
  }
end

function Mutation:stage_hunk(filename, hunk)
  local git_blob = git_service:get_blob(filename)

  if not git_blob:is_tracked() then
    return git_blob:stage()
  end

  return git_blob:stage_hunk(hunk)
end

function Mutation:unstage_hunk(filename, hunk)
  local git_blob = git_service:get_blob(filename)

  if not git_blob:is_in_remote() then
    return git_blob:unstage()
  end

  return git_blob:unstage_hunk(hunk)
end

function Mutation:stage_file(filename) return self.git_repository:stage_file(filename) end

function Mutation:unstage_file(filename) return self.git_repository:unstage_file(filename) end

function Mutation:reset_file(filename)
  if self.git_repository:is_in_remote(filename) then
    return self.git_repository:reset(filename)
  end

  return self.git_repository:clean(filename)
end

return Mutation
