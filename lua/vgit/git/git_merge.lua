local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_merge = {}

function git_merge.merge(reponame, commit, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not commit then return nil, { 'commit/branch is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('merge')

  if opts.ff_only then
    query:raw_arg('--ff-only')
  elseif opts.no_ff then
    query:raw_arg('--no-ff')
  elseif opts.ff then
    query:raw_arg('--ff')
  end

  if opts.squash then query:raw_arg('--squash') end

  if opts.no_commit then query:raw_arg('--no-commit') end

  if opts.commit then query:raw_arg('--commit') end

  if opts.strategy then
    query:raw_arg('-s')
    query:raw_arg(opts.strategy)
  end

  if opts.strategy_option then
    query:raw_arg('-X')
    query:raw_arg(opts.strategy_option)
  end

  if opts.message then
    query:raw_arg('-m')
    query:raw_arg(opts.message)
  end

  if opts.edit then query:raw_arg('--edit') end

  if opts.no_edit then query:raw_arg('--no-edit') end

  if opts.log then
    if type(opts.log) == 'number' then
      query:raw_arg('--log=' .. opts.log)
    else
      query:raw_arg('--log')
    end
  end

  if opts.stat then query:raw_arg('--stat') end

  if opts.no_stat then query:raw_arg('--no-stat') end

  if opts.verify_signatures then query:raw_arg('--verify-signatures') end

  if opts.allow_unrelated_histories then query:raw_arg('--allow-unrelated-histories') end

  query:raw_arg(commit)

  return query:execute()
end

function git_merge.abort(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('merge', '--abort'):execute()
end

function git_merge.continue(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('merge', '--continue'):execute()
end

function git_merge.quit(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('merge', '--quit'):execute()
end

function git_merge.in_progress(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local fs = require('vgit.core.fs')
  local git_dir = string.format('%s/.git', reponame)

  return fs.exists(string.format('%s/MERGE_HEAD', git_dir))
end

function git_merge.base(reponame, commit1, commit2)
  if not reponame then return nil, { 'reponame is required' } end
  if not commit1 then return nil, { 'commit1 is required' } end
  if not commit2 then return nil, { 'commit2 is required' } end

  local result, err = GitQueryBuilder(reponame):raw_args('merge-base', commit1, commit2):execute()

  if err then return nil, err end
  return result[1], nil
end

function git_merge.is_ancestor(reponame, ancestor, descendant)
  if not reponame then return nil, { 'reponame is required' } end
  if not ancestor then return nil, { 'ancestor is required' } end
  if not descendant then return nil, { 'descendant is required' } end

  local _, _, code = GitQueryBuilder(reponame):raw_args('merge-base', '--is-ancestor', ancestor, descendant):execute()

  return code == 0
end

return git_merge
