local lazy = require('vgit.core.lazy')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')
local fs = lazy('vgit.core.fs')

local git_bisect = {}

-- Start bisect session
function git_bisect.start(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('bisect', 'start')

  if opts.no_checkout then query:raw_arg('--no-checkout') end

  if opts.first_parent then query:raw_arg('--first-parent') end

  -- Add bad and good commits if provided
  if opts.bad then query:raw_arg(opts.bad) end

  if opts.good then
    if type(opts.good) == 'string' then
      query:raw_arg(opts.good)
    elseif type(opts.good) == 'table' then
      for _, commit in ipairs(opts.good) do
        query:raw_arg(commit)
      end
    end
  end

  -- Path limiters
  if opts.paths then
    query:raw_arg('--')
    if type(opts.paths) == 'string' then
      query:raw_arg(opts.paths)
    elseif type(opts.paths) == 'table' then
      for _, path in ipairs(opts.paths) do
        query:raw_arg(path)
      end
    end
  end

  return query:execute()
end

-- Mark current commit as bad
function git_bisect.bad(reponame, commit)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', 'bad')

  if commit then query:raw_arg(commit) end

  return query:execute()
end

-- Mark current commit as good
function git_bisect.good(reponame, commits)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', 'good')

  if commits then
    if type(commits) == 'string' then
      query:raw_arg(commits)
    elseif type(commits) == 'table' then
      for _, commit in ipairs(commits) do
        query:raw_arg(commit)
      end
    end
  end

  return query:execute()
end

-- Skip current commit (can't test)
function git_bisect.skip(reponame, commits)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', 'skip')

  if commits then
    if type(commits) == 'string' then
      query:raw_arg(commits)
    elseif type(commits) == 'table' then
      for _, commit in ipairs(commits) do
        query:raw_arg(commit)
      end
    end
  end

  return query:execute()
end

-- Reset bisect session
function git_bisect.reset(reponame, commit)
  if not reponame then return nil, { 'reponame is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', 'reset')

  if commit then query:raw_arg(commit) end

  return query:execute()
end

-- Visualize bisect session
function git_bisect.visualize(reponame, opts)
  if not reponame then return nil, { 'reponame is required' } end

  opts = opts or {}
  local query = GitQueryBuilder(reponame):raw_args('bisect', 'visualize')

  -- Add any additional arguments
  if opts.args then
    for _, arg in ipairs(opts.args) do
      query:raw_arg(arg)
    end
  end

  return query:execute()
end

-- View bisect log
function git_bisect.log(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('bisect', 'log'):execute()
end

-- Replay bisect log
function git_bisect.replay(reponame, logfile)
  if not reponame then return nil, { 'reponame is required' } end
  if not logfile then return nil, { 'logfile is required' } end

  return GitQueryBuilder(reponame):raw_args('bisect', 'replay', logfile):execute()
end

-- Run automated bisect with a command
function git_bisect.run(reponame, command, args)
  if not reponame then return nil, { 'reponame is required' } end
  if not command then return nil, { 'command is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', 'run', command)

  if args then
    if type(args) == 'string' then
      query:raw_arg(args)
    elseif type(args) == 'table' then
      for _, arg in ipairs(args) do
        query:raw_arg(arg)
      end
    end
  end

  return query:execute()
end

-- Check if bisect is in progress
function git_bisect.in_progress(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local git_dir = string.format('%s/.git', reponame)

  return fs.exists(string.format('%s/BISECT_LOG', git_dir))
end

-- Get bisect status
function git_bisect.status(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local git_dir = string.format('%s/.git', reponame)

  local status = {
    in_progress = false,
    log = nil,
    start = nil,
    good = {},
    bad = {},
  }

  if not fs.exists(string.format('%s/BISECT_LOG', git_dir)) then return status, nil end

  status.in_progress = true

  -- Read bisect log
  local log_file = fs.read_file(string.format('%s/BISECT_LOG', git_dir))
  if log_file then
    status.log = log_file

    -- Parse log for good/bad commits
    for _, line in ipairs(log_file) do
      local good_commit = line:match('^git bisect good (%S+)')
      if good_commit then table.insert(status.good, good_commit) end

      local bad_commit = line:match('^git bisect bad (%S+)')
      if bad_commit then table.insert(status.bad, bad_commit) end

      local start_marker = line:match('^git bisect start')
      if start_marker then status.start = line end
    end
  end

  -- Read BISECT_START
  local start_file = fs.read_file(string.format('%s/BISECT_START', git_dir))
  if start_file and start_file[1] then status.original_head = start_file[1]:match('^%s*(.-)%s*$') end

  return status, nil
end

-- Mark current commit with custom term
function git_bisect.terms(reponame, term, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not term then return nil, { 'term is required' } end

  local query = GitQueryBuilder(reponame):raw_args('bisect', term)

  if commit then query:raw_arg(commit) end

  return query:execute()
end

return git_bisect
