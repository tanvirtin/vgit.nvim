local utils = require('vgit.core.utils')
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

function git_log.count(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({
    '-C',
    reponame,
    'rev-list',
    '--count',
    '--all',
  })
end

function git_log.list(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}

  local filename = opts.filename
  local from = opts.from
  local count = opts.count
  local stashed = opts.stashed

  local args = {
    '-C',
    reponame,
    '--no-pager',
  }

  if stashed then
    args = utils.list.merge(args, { 'stash', 'list' })
  else
    args = utils.list.merge(args, { 'log' })
  end

  args = utils.list.merge(args, { '--color=never', git_log.format })

  if from and count then
    args = utils.list.merge(args, {
      string.format('--skip=%s', filename),
      '-n',
      count,
    })
  end

  if filename then args = utils.list.merge(args, { filename }) end

  local result, err = gitcli.run(args)
  if err then return nil, err end

  local logs = {}
  for i = 1, #result do
    logs[i] = GitLog(result[i])
  end

  return logs
end

return git_log
