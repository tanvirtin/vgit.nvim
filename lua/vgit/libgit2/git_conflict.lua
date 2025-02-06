local ffi = require('ffi')
local libgit2 = require('vgit.libgit2')
local git_conflict = require('vgit.git.git_conflict')

local git_has_conflict = git_conflict.has_conflict

function git_conflict.has_conflict(reponame, filename)
  if not libgit2.is_enabled() then return git_has_conflict(reponame, filename) end

  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local repo_ptr = ffi.new('git_repository*[1]')
  local ret = libgit2.cli.git_repository_open(repo_ptr, reponame)
  if ret ~= 0 then return libgit2.error() end

  local index_ptr = ffi.new('git_index*[1]')
  ret = libgit2.cli.git_repository_index(index_ptr, repo_ptr[0])
  if ret ~= 0 then
    libgit2.cli.git_repository_free(repo_ptr[0])
    return libgit2.error()
  end

  local has_conflict = false
  for stage = 1, 3 do
    local entry = libgit2.cli.git_index_get_bypath(index_ptr[0], filename, stage)
    if entry ~= nil then
      has_conflict = true
      break
    end
  end

  libgit2.cli.git_index_free(index_ptr[0])
  libgit2.cli.git_repository_free(repo_ptr[0])

  return has_conflict
end

return git_conflict
