local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local console = lazy('vgit.core.console')
local GitPatch = lazy('vgit.git.GitPatch')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_stager = {}

function git_stager.stage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local _, err = GitQueryBuilder(reponame):raw_args('--no-pager', 'add', '--', filename or '.'):execute()
  if err then return nil, err end
  return nil, nil
end

function git_stager.unstage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local _, err = GitQueryBuilder(reponame):raw_args('reset', '-q', 'HEAD', '--', filename or '.'):execute()
  if err then return nil, err end
  return nil, nil
end

local function apply_hunk_patch(reponame, filename, hunk, apply_args)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = GitPatch(filename, hunk)
  local patch_filename = fs.tmpname()

  local _, write_err = fs.write_file(patch_filename, patch)
  if write_err then
    console.debug.error(write_err)
    return nil, write_err
  end

  local args = { '--no-pager', 'apply' }
  for i = 1, #apply_args do
    args[#args + 1] = apply_args[i]
  end
  args[#args + 1] = '--whitespace=nowarn'
  args[#args + 1] = '--unidiff-zero'
  args[#args + 1] = patch_filename

  local _, err = GitQueryBuilder(reponame):raw_args(unpack(args)):execute()

  fs.remove_file(patch_filename)

  return nil, err
end

function git_stager.stage_hunk(reponame, filename, hunk)
  return apply_hunk_patch(reponame, filename, hunk, { '--cached' })
end

function git_stager.unstage_hunk(reponame, filename, hunk)
  return apply_hunk_patch(reponame, filename, hunk, { '--reverse', '--cached' })
end

function git_stager.reset_hunk(reponame, filename, hunk)
  return apply_hunk_patch(reponame, filename, hunk, { '--reverse' })
end

return git_stager
