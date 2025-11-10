local fs = require('vgit.core.fs')
local gitcli = require('vgit.git.gitcli')
local GitPatch = require('vgit.git.GitPatch')

local git_stager = {}

function git_stager.stage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'add',
    '--',
    filename or '.',
  })
end

function git_stager.unstage(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'reset',
    '-q',
    'HEAD',
    '--',
    filename or '.',
  })
end

function git_stager.stage_hunk(reponame, filename, hunk)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = GitPatch(filename, hunk)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  local _, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'apply',
    '--cached',
    '--whitespace=nowarn',
    '--unidiff-zero',
    patch_filename,
  })

  fs.remove_file(patch_filename)

  return nil, err
end

function git_stager.unstage_hunk(reponame, filename, hunk)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = GitPatch(filename, hunk)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  local _, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'apply',
    '--reverse',
    '--cached',
    '--whitespace=nowarn',
    '--unidiff-zero',
    patch_filename,
  })

  fs.remove_file(patch_filename)

  return nil, err
end

-- Reset (discard) a hunk in the working directory
function git_stager.reset_hunk(reponame, filename, hunk)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end

  local patch = GitPatch(filename, hunk)
  local patch_filename = fs.tmpname()

  fs.write_file(patch_filename, patch)

  -- Apply the patch in reverse to the working directory (not staged)
  local _, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'apply',
    '--reverse',
    '--whitespace=nowarn',
    '--unidiff-zero',
    patch_filename,
  })

  fs.remove_file(patch_filename)

  return nil, err
end

return git_stager
