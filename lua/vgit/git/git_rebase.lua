local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_rebase = {}

function git_rebase.rebase(reponame, upstream, opts)
  if not reponame or reponame == '' then return nil, { 'reponame is required' } end
  if not upstream or upstream == '' then return nil, { 'upstream is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('rebase')

  if opts.interactive or opts.i then query:raw_arg('-i') end

  if opts.preserve_merges then query:raw_arg('--preserve-merges') end

  if opts.rebase_merges then query:raw_arg('--rebase-merges') end

  if opts.strategy then
    query:raw_arg('-s')
    query:raw_arg(opts.strategy)
  end

  if opts.strategy_option then
    query:raw_arg('-X')
    query:raw_arg(opts.strategy_option)
  end

  if opts.keep_empty then query:raw_arg('--keep-empty') end

  if opts.keep_base then query:raw_arg('--keep-base') end

  if opts.autosquash then query:raw_arg('--autosquash') end

  if opts.no_autosquash then query:raw_arg('--no-autosquash') end

  if opts.autostash then query:raw_arg('--autostash') end

  if opts.no_autostash then query:raw_arg('--no-autostash') end

  if opts.fork_point then query:raw_arg('--fork-point') end

  if opts.no_fork_point then query:raw_arg('--no-fork-point') end

  if opts.onto then
    query:raw_arg('--onto')
    query:raw_arg(opts.onto)
  end

  if opts.root then query:raw_arg('--root') end

  query:raw_arg(upstream)

  if opts.branch then query:raw_arg(opts.branch) end

  return query:execute({ env = opts.env })
end

function git_rebase.continue(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--continue'):execute()
end

function git_rebase.skip(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--skip'):execute()
end

function git_rebase.abort(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--abort'):execute()
end

function git_rebase.quit(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--quit'):execute()
end

function git_rebase.edit_todo(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--edit-todo'):execute()
end

function git_rebase.show_current_patch(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('rebase', '--show-current-patch'):execute()
end

function git_rebase.in_progress(reponame)
  if not reponame or reponame == '' then return false end

  local git_dir = string.format('%s/.git', reponame)

  return fs.exists(string.format('%s/rebase-merge', git_dir)) or fs.exists(string.format('%s/rebase-apply', git_dir))
end

function git_rebase.status(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local git_dir = string.format('%s/.git', reponame)

  local status = {
    in_progress = false,
    interactive = false,
    current = nil,
    total = nil,
    onto = nil,
    head_name = nil,
  }

  local rebase_merge_dir = string.format('%s/rebase-merge', git_dir)
  if fs.exists(rebase_merge_dir) then
    status.in_progress = true
    status.interactive = true

    local msgnum = fs.read_file(string.format('%s/msgnum', rebase_merge_dir))
    local end_num = fs.read_file(string.format('%s/end', rebase_merge_dir))
    if msgnum and msgnum[1] then
      local trimmed = msgnum[1]:match('^%s*(.-)%s*$')
      status.current = tonumber(trimmed)
    end
    if end_num and end_num[1] then
      local trimmed = end_num[1]:match('^%s*(.-)%s*$')
      status.total = tonumber(trimmed)
    end

    local onto = fs.read_file(string.format('%s/onto', rebase_merge_dir))
    if onto and onto[1] then status.onto = onto[1]:match('^%s*(.-)%s*$') end

    local head_name = fs.read_file(string.format('%s/head-name', rebase_merge_dir))
    if head_name and head_name[1] then status.head_name = head_name[1]:match('^%s*(.-)%s*$') end

    return status, nil
  end

  local rebase_apply_dir = string.format('%s/rebase-apply', git_dir)
  if fs.exists(rebase_apply_dir) then
    status.in_progress = true
    status.interactive = false

    local next_file = fs.read_file(string.format('%s/next', rebase_apply_dir))
    local last_file = fs.read_file(string.format('%s/last', rebase_apply_dir))
    if next_file and next_file[1] then
      local trimmed = next_file[1]:match('^%s*(.-)%s*$')
      status.current = tonumber(trimmed)
    end
    if last_file and last_file[1] then
      local trimmed = last_file[1]:match('^%s*(.-)%s*$')
      status.total = tonumber(trimmed)
    end

    local head_name = fs.read_file(string.format('%s/head-name', rebase_apply_dir))
    if head_name and head_name[1] then status.head_name = head_name[1]:match('^%s*(.-)%s*$') end

    return status, nil
  end

  return status, nil
end

return git_rebase
