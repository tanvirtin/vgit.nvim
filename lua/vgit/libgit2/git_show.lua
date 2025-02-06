local ffi = require('ffi')
local libgit2 = require('vgit.libgit2')
local git_show = require('vgit.git.git_show')

local git_lines = git_show.lines

function git_show.lines(reponame, filename, commit_hash)
  if not libgit2.is_enabled() then return git_lines(reponame, filename, commit_hash) end

  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local repo_ptr = ffi.new('git_repository*[1]')
  local ret = libgit2.cli.git_repository_open(repo_ptr, reponame)
  if ret ~= 0 then return libgit2.error() end

  local blob = nil
  local repo = repo_ptr[0]

  if not commit_hash then
    local index_ptr = ffi.new('git_index*[1]')
    ret = libgit2.cli.git_repository_index(index_ptr, repo)
    if ret ~= 0 then
      libgit2.cli.git_repository_free(repo)
      return libgit2.error()
    end
    local index = index_ptr[0]

    local entry = libgit2.cli.git_index_get_bypath(index, filename, 0)
    if entry == nil then
      libgit2.cli.git_index_free(index)
      libgit2.cli.git_repository_free(repo)

      return nil, { 'file not found in index' }
    end

    local entry_oid = entry.id
    local blob_ptr = ffi.new('git_blob*[1]')
    ret = libgit2.cli.git_blob_lookup(blob_ptr, repo, entry_oid)
    if ret ~= 0 then
      libgit2.cli.git_index_free(index)
      libgit2.cli.git_repository_free(repo)

      return libgit2.error()
    end
    blob = blob_ptr[0]

    libgit2.cli.git_index_free(index)
  else
    local object_ptr = ffi.new('git_object*[1]')
    ret = libgit2.cli.git_revparse_single(object_ptr, repo, commit_hash)
    if ret ~= 0 then
      libgit2.cli.git_repository_free(repo)
      return libgit2.error()
    end
    local object = object_ptr[0]

    local obj_type = libgit2.cli.git_object_type(object)
    if obj_type ~= libgit2.cli.GIT_OBJECT_COMMIT and obj_type ~= libgit2.cli.GIT_OBJECT_TREE then
      libgit2.cli.git_object_free(object)
      libgit2.cli.git_repository_free(repo)

      return nil, { 'object is not a commit or tree' }
    end

    local tree_ptr = ffi.new('git_tree*[1]')
    if obj_type == libgit2.cli.GIT_OBJECT_COMMIT then
      local commit = ffi.cast('git_commit*', object)
      ret = libgit2.cli.git_commit_tree(tree_ptr, commit)
    else
      tree_ptr[0] = ffi.cast('git_tree*', object)
      ret = 0
    end

    if ret ~= 0 then
      libgit2.cli.git_object_free(object)
      libgit2.cli.git_repository_free(repo)
      return libgit2.error()
    end
    local tree = tree_ptr[0]

    local entry_ptr = ffi.new('git_tree_entry*[1]')
    ret = libgit2.cli.git_tree_entry_bypath(entry_ptr, tree, filename)
    if ret ~= 0 then
      libgit2.cli.git_object_free(object)
      if obj_type == libgit2.cli.GIT_OBJECT_COMMIT then libgit2.cli.git_tree_free(tree) end
      libgit2.cli.git_repository_free(repo)

      return libgit2.error()
    end
    local entry = entry_ptr[0]

    local entry_oid = libgit2.cli.git_tree_entry_id(entry)
    local blob_ptr = ffi.new('git_blob*[1]')
    ret = libgit2.cli.git_blob_lookup(blob_ptr, repo, entry_oid)
    if ret ~= 0 then
      libgit2.cli.git_object_free(object)
      if obj_type == libgit2.cli.GIT_OBJECT_COMMIT then libgit2.cli.git_tree_free(tree) end
      libgit2.cli.git_repository_free(repo)

      return libgit2.error()
    end
    blob = blob_ptr[0]

    libgit2.cli.git_object_free(object)

    if obj_type == libgit2.cli.GIT_OBJECT_COMMIT then libgit2.cli.git_tree_free(tree) end
  end

  if not blob then return nil, { 'blob not found' } end

  local content = ffi.string(libgit2.cli.git_blob_rawcontent(blob), libgit2.cli.git_blob_rawsize(blob))

  local lines = {}
  for line in content:gmatch('([^\n]*)\n') do
    lines[#lines + 1] = line
  end

  local lastLine = content:match('([^\n]*)$')
  if lastLine ~= '' or content == '' then lines[#lines + 1] = lastLine end

  libgit2.cli.git_blob_free(blob)
  libgit2.cli.git_repository_free(repo)

  return lines
end

return git_show
