local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_revert = {}

function git_revert.revert(reponame, commits, opts)
  if not reponame or reponame == '' then return nil, { 'reponame is required' } end
  if not commits or commits == '' then return nil, { 'commits is required' } end
  if type(commits) == 'table' and #commits == 0 then return nil, { 'commits is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('revert')

  if opts.edit or opts.e then query:raw_arg('-e') end

  if opts.no_edit then query:raw_arg('--no-edit') end

  if opts.no_commit or opts.n then query:raw_arg('-n') end

  if opts.mainline then
    query:raw_arg('-m')
    query:raw_arg(tostring(opts.mainline))
  end

  if opts.strategy then
    query:raw_arg('-s')
    query:raw_arg(opts.strategy)
  end

  if opts.strategy_option then
    query:raw_arg('-X')
    query:raw_arg(opts.strategy_option)
  end

  if opts.signoff or opts.s then query:raw_arg('-s') end

  if type(commits) == 'string' then
    query:raw_arg(commits)
  elseif type(commits) == 'table' then
    for _, commit in ipairs(commits) do
      query:raw_arg(commit)
    end
  end

  return query:execute()
end

function git_revert.continue(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('revert', '--continue'):execute()
end

function git_revert.skip(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('revert', '--skip'):execute()
end

function git_revert.abort(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('revert', '--abort'):execute()
end

function git_revert.quit(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('revert', '--quit'):execute()
end

function git_revert.in_progress(reponame)
  if not reponame or reponame == '' then return false end

  local git_dir = string.format('%s/.git', reponame)

  return fs.exists(string.format('%s/REVERT_HEAD', git_dir))
end

return git_revert
