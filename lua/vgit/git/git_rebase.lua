local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local git_repo = lazy('vgit.git.git_repo')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_rebase = {}

local rebase_flags = {
  { opt = 'rebase_merges', flag = '--rebase-merges' },
  { opt = 'keep_empty', flag = '--keep-empty' },
  { opt = 'keep_base', flag = '--keep-base' },
  { opt = 'autosquash', flag = '--autosquash' },
  { opt = 'no_autosquash', flag = '--no-autosquash' },
  { opt = 'autostash', flag = '--autostash' },
  { opt = 'no_autostash', flag = '--no-autostash' },
  { opt = 'fork_point', flag = '--fork-point' },
  { opt = 'no_fork_point', flag = '--no-fork-point' },
  { opt = 'root', flag = '--root' },
}

function git_rebase.rebase(reponame, upstream, opts)
  if not reponame or reponame == '' then return nil, { 'reponame is required' } end
  if not upstream or upstream == '' then return nil, { 'upstream is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_arg('rebase')

  if opts.interactive or opts.i then query:raw_arg('-i') end

  if opts.strategy then query:raw_arg('-s'):raw_arg(opts.strategy) end
  if opts.strategy_option then query:raw_arg('-X'):raw_arg(opts.strategy_option) end

  for _, entry in ipairs(rebase_flags) do
    if opts[entry.opt] then query:raw_arg(entry.flag) end
  end

  if opts.onto then query:raw_arg('--onto'):raw_arg(opts.onto) end

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

  local git_dir = git_repo.git_dir(reponame)
  if not git_dir then return false end

  return fs.exists(string.format('%s/rebase-merge', git_dir)) or fs.exists(string.format('%s/rebase-apply', git_dir))
end

local function read_trimmed(dir, filename)
  local content = fs.read_file(string.format('%s/%s', dir, filename))
  if content and content[1] then return content[1]:match('^%s*(.-)%s*$') end
  return nil
end

function git_rebase.status(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local git_dir = git_repo.git_dir(reponame)
  if not git_dir then return nil, { 'git directory not found' } end

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
    status.current = tonumber(read_trimmed(rebase_merge_dir, 'msgnum'))
    status.total = tonumber(read_trimmed(rebase_merge_dir, 'end'))
    status.onto = read_trimmed(rebase_merge_dir, 'onto')
    status.head_name = read_trimmed(rebase_merge_dir, 'head-name')
    return status, nil
  end

  local rebase_apply_dir = string.format('%s/rebase-apply', git_dir)
  if fs.exists(rebase_apply_dir) then
    status.in_progress = true
    status.interactive = false
    status.current = tonumber(read_trimmed(rebase_apply_dir, 'next'))
    status.total = tonumber(read_trimmed(rebase_apply_dir, 'last'))
    status.head_name = read_trimmed(rebase_apply_dir, 'head-name')
    return status, nil
  end

  return status, nil
end

return git_rebase
