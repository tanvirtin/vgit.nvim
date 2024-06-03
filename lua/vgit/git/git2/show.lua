local gitcli = require('vgit.git.git2.gitcli')

local show = {}

function show.lines(reponame, filename, commit_hash)
  if not reponame then return nil, { 'reponame is required' } end
  commit_hash = commit_hash or ''
  return gitcli.run({
    '-C',
    reponame,
    'show',
    string.format('%s:%s', commit_hash, filename),
  })
end

return show
