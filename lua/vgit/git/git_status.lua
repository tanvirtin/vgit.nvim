local gitcli = require('vgit.git.gitcli')
local GitStatus = require('vgit.git.GitStatus')

local git_status = {}

function git_status.ls(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'status',
    '-u',
    '-s',
    '--no-renames',
    '--ignore-submodules',
    '--',
    filename or '.',
  })
  if err then return nil, err end

  local files = {}
  for i = 1, #result do
    local line = result[i]
    files[#files + 1] = GitStatus(line)
  end

  if filename then return files[1] end
  return files
end

function git_status.tree(reponame, opts)
  opts = opts or {}
  if not reponame then return nil, { 'reponame is required' } end

  local commit_hash = opts.commit_hash
  local parent_hash = opts.parent_hash
  local empty_hash = '4b825dc642cb6eb9a060e54bf8d69288fbee4904'
  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'diff-tree',
    '--no-commit-id',
    '--name-only',
    '-r',
    commit_hash,
    parent_hash == '' and empty_hash or parent_hash,
  })
  if err then return nil, err end

  local files = {}
  for i = 1, #result do
    local line = result[i]
    files[#files + 1] = GitStatus(string.format('%s %s', '--', line))
  end

  return files
end

return git_status
