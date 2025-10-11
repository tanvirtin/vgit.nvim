local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_show = {}

function git_show.lines(reponame, filename, commit_hash)
  if not reponame then return nil, { 'reponame is required' } end
  commit_hash = commit_hash or ''
  return GitQueryBuilder(reponame):show():raw_arg(string.format('%s:%s', commit_hash, filename)):execute()
end

return git_show
