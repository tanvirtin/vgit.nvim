local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_cherry = {}

function git_cherry.pick(reponame, commits, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not commits then return nil, { 'commits is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('cherry-pick')

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

  if opts.allow_empty then query:raw_arg('--allow-empty') end

  if opts.allow_empty_message then query:raw_arg('--allow-empty-message') end

  if opts.keep_redundant_commits then query:raw_arg('--keep-redundant-commits') end

  if opts.signoff or opts.s then query:raw_arg('-s') end

  if opts.ff then query:raw_arg('--ff') end

  if type(commits) == 'string' then
    query:raw_arg(commits)
  elseif type(commits) == 'table' then
    for _, commit in ipairs(commits) do
      query:raw_arg(commit)
    end
  end

  return query:execute()
end

function git_cherry.continue(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('cherry-pick', '--continue'):execute()
end

function git_cherry.skip(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('cherry-pick', '--skip'):execute()
end

function git_cherry.abort(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('cherry-pick', '--abort'):execute()
end

function git_cherry.quit(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('cherry-pick', '--quit'):execute()
end

function git_cherry.in_progress(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local fs = require('vgit.core.fs')
  local git_dir = string.format('%s/.git', reponame)

  return fs.exists(string.format('%s/CHERRY_PICK_HEAD', git_dir))
end

function git_cherry.list(reponame, upstream, head, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not upstream then return nil, { 'upstream is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('cherry', '-v')

  if opts.abbrev then query:raw_arg('--abbrev=' .. opts.abbrev) end

  query:raw_arg(upstream)

  if head then query:raw_arg(head) end

  local result, err = query:execute()
  if err then return nil, err end

  local commits = {}
  for _, line in ipairs(result) do
    local status, hash, message = line:match('^([%+%-])%s+(%S+)%s+(.*)$')
    if status and hash then
      commits[#commits + 1] = {
        hash = hash,
        message = message,
        in_upstream = status == '-',
        not_in_upstream = status == '+',
      }
    end
  end

  return commits, nil
end

return git_cherry
