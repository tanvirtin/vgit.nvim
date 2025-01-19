local GitLog = require('vgit.git.GitLog')
local gitcli = require('vgit.git.gitcli')

local git_log = { format = '--pretty=format:"%H\x1F%P\x1F%at\x1F%an\x1F%ae\x1F%s"' }

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

return git_log
