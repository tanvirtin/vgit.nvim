local utils = require('vgit.core.utils')
local gitcli = require('vgit.git.gitcli')
local GitStatus = require('vgit.git.GitStatus')

local git_status = {}

function git_status.get(reponame, filename, commit_hash)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local args = {
    '-C',
    reponame,
    '--no-pager',
  }

  if commit_hash then
    args = utils.list.merge(args, {
      'diff-tree',
      '--no-commit-id',
      '--name-status',
      '-r',
      commit_hash .. "^",
      commit_hash,
      '--',
      filename
    })
  else
    args = utils.list.merge(args, {
      'status',
      '-u',
      '-s',
      '--no-renames',
      '--ignore-submodules',
      '--',
      filename
    })
  end

  local result, err = gitcli.run(args)
  if err then return nil, err end
  if #result == 0 then return nil, { 'no status found' } end

  if commit_hash then
    local status, path = result[1]:match('(%w+)%s+(.+)')
    return GitStatus(string.format('%s  %s', status or ' ', path or filename))
  end

  return GitStatus(result[1])
end

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
    '--name-status',
    '-r',
    parent_hash == '' and empty_hash or parent_hash,
    commit_hash,
  })
  if err then return nil, err end

  local files = {}
  for i = 1, #result do
    local status, path = result[i]:match('(%w+)%s+(.+)')
    files[#files + 1] = GitStatus(string.format('%s  %s', status, path))
  end

  return files
end

return git_status
