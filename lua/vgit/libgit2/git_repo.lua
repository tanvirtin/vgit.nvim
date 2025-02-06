local ffi = require('ffi')
local libgit2 = require('vgit.libgit2')
local git_repo = require('vgit.git.git_repo')

local git_has = git_repo.has
local git_exists = git_repo.exists
local git_ignores = git_repo.ignores
local git_discover = git_repo.discover

function git_repo.discover(filepath, opts)
  if not libgit2.is_enabled() then return git_discover(filepath, opts) end

  opts = opts or {}
  local git_dirname = opts.git_dirname
  filepath = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()

  local buf = ffi.new('git_buf')
  local ret = libgit2.cli.git_repository_discover(buf, filepath, 1, nil)
  if ret ~= 0 then
    libgit2.cli.git_buf_free(buf)
    return libgit2.error()
  end

  if not buf.ptr then
    libgit2.cli.git_buf_free(buf)
    return nil, { '.git discovery failed' }
  end

  local dirname = ffi.string(buf.ptr)
  if not dirname then
    libgit2.cli.git_buf_free(buf)
    return nil, { '.git discovery failed' }
  end

  libgit2.cli.git_buf_free(buf)

  if git_dirname == true then return dirname end
  return dirname:gsub('%.git/$', '')
end

function git_repo.exists(filepath)
  if not libgit2.is_enabled() then return git_exists(filepath) end
  local reponame, err = git_repo.discover(filepath, { git_dirname = true })
  if err then return false end
  return reponame ~= nil
end

function git_repo.ignores(reponame, filename)
  if not libgit2.is_enabled() then return git_ignores(reponame, filename) end

  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local repo_ptr = ffi.new('git_repository*[1]')
  local ret = libgit2.cli.git_repository_open_ext(repo_ptr, reponame, 1, nil)
  if ret ~= 0 then return nil, libgit2.error() end

  local ignored_ptr = ffi.new('int[1]')
  ret = libgit2.cli.git_ignore_path_is_ignored(ignored_ptr, repo_ptr[0], filename)

  libgit2.cli.git_repository_free(repo_ptr[0])

  if ret ~= 0 then return nil, libgit2.error() end
  return ignored_ptr[0] == 1
end

function git_repo.has(reponame, filename, commit)
  if not libgit2.is_enabled() then return git_has(reponame, filename, commit) end

  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  commit = commit or 'HEAD'

  local repo_ptr = ffi.new('git_repository*[1]')
  local ret = libgit2.cli.git_repository_open_ext(repo_ptr, reponame, 1, nil)
  if ret ~= 0 then return nil, libgit2.error() end

  local index_ptr = ffi.new('git_index*[1]')
  ret = libgit2.cli.git_repository_index(index_ptr, repo_ptr[0])
  if ret == 0 then
    local entry = libgit2.cli.git_index_get_bypath(index_ptr[0], filename, 0)
    libgit2.cli.git_index_free(index_ptr[0])

    if entry ~= nil then
      libgit2.cli.git_repository_free(repo_ptr[0])
      return true
    end
  end

  local object_ptr = ffi.new('git_object*[1]')
  ret = libgit2.cli.git_revparse_single(object_ptr, repo_ptr[0], commit)
  if ret ~= 0 then
    libgit2.cli.git_repository_free(repo_ptr[0])
    return nil, libgit2.error()
  end

  if libgit2.cli.git_object_type(object_ptr[0]) ~= 1 then
    libgit2.cli.git_object_free(object_ptr[0])
    libgit2.cli.git_repository_free(repo_ptr[0])

    return nil, { 'Reference does not point to a commit' }
  end

  local tree_ptr = ffi.new('git_tree*[1]')
  local commit_obj = ffi.cast('git_commit *', object_ptr[0])
  ret = libgit2.cli.git_commit_tree(tree_ptr, commit_obj)
  if ret ~= 0 then
    libgit2.cli.git_object_free(object_ptr[0])
    libgit2.cli.git_repository_free(repo_ptr[0])

    return nil, libgit2.error()
  end

  local entry_ptr = ffi.new('git_tree_entry*[1]')
  ret = libgit2.cli.git_tree_entry_bypath(entry_ptr, tree_ptr[0], filename)

  libgit2.cli.git_object_free(object_ptr[0])
  libgit2.cli.git_tree_free(tree_ptr[0])
  libgit2.cli.git_repository_free(repo_ptr[0])

  if ret == 0 then
    libgit2.cli.git_tree_entry_free(entry_ptr[0])
    return true
  end

  return false
end

return git_repo
