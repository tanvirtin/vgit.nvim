local GitLog = require('vgit.git.GitLog')
local gitcli = require('vgit.git.gitcli')

local git_stash = {}

local git_log = { format = '--pretty=format:"%H\x1F%P\x1F%at\x1F%an\x1F%ae\x1F%s"' }

function git_stash.add(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'stash' })
end

function git_stash.apply(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'apply',
    stash_index,
  })
end

function git_stash.pop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'pop',
    stash_index,
  })
end

function git_stash.drop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'drop',
    stash_index,
  })
end

function git_stash.clear(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'stash', 'clear' })
end

function git_stash.list(reponame)
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
    logs[#logs + 1] = GitLog(result[i], rev_count)
  end

  return logs
end

return git_stash
