local GitLog = require('vgit.git.GitLog')
local gitcli = require('vgit.git.gitcli')

local git_log = { format = '--pretty=format:"%H-%P-%at-%an-%ae-%s"' }

function git_log.get(reponame, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not commit then return nil, { 'commit is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    'show',
    commit,
    '--color=never',
    git_log.format,
    '--no-patch',
  })

  if err then return nil, err end
  return GitLog(result[1])
end

function git_log.list(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'log',
    '--color=never',
    git_log.format,
    filename,
  })

  if err then return nil, err end

  local logs = {}
  for i = 1, #result do
    logs[i] = GitLog(result[i])
  end

  return logs
end

function git_log.list_stash(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local result, err = gitcli.run({
    '-C',
    reponame,
    '--no-pager',
    'stash',
    'list',
    '--color=never',
    git_log.format,
  })

  if err then return nil, err end

  local logs = {}
  local rev_count = 0
  for i = 1, #result do
    rev_count = rev_count + 1
    logs[i] = GitLog(result[i], rev_count)
  end

  return logs
end

return git_log
