local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_show = {}

function git_show.lines(reponame, filename, commit_hash)
  if not reponame then return nil, { 'reponame is required' } end

  commit_hash = commit_hash or ''

  -- Normalize 'index' to ':' for git reference
  if commit_hash == 'index' then commit_hash = ':' end

  local ref
  if commit_hash == ':' then
    ref = string.format(':%s', filename)
  else
    ref = string.format('%s:%s', commit_hash, filename)
  end

  return GitQueryBuilder(reponame):show():raw_arg(ref):execute()
end

return git_show
