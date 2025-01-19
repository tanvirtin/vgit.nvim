local gitcli = require('vgit.git.gitcli')

local git_show = {}

function git_show.add(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'stash' })
end

function git_show.apply(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'apply',
    stash_index
  })
end

function git_show.pop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'pop',
    stash_index
  })
end

function git_show.drop(reponame, stash_index)
  if not reponame then return nil, { 'reponame is required' } end
  if not stash_index then return nil, { 'stash_index is required' } end

  return gitcli.run({
    '-C',
    reponame,
    'stash',
    'drop',
    stash_index
  })
end

function git_show.clear(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return gitcli.run({ '-C', reponame, 'stash', 'clear' })
end

return git_show
