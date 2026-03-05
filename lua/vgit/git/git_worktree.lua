local lazy = require('vgit.core.lazy')

local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_worktree = {}

local function parse_porcelain(lines)
  local worktrees = {}
  local current = {}

  for i = 1, #lines do
    local line = lines[i]

    if line == '' then
      if current.path then
        worktrees[#worktrees + 1] = current
      end
      current = {}
    else
      local key, value = line:match('^(%S+)%s*(.*)')
      if key == 'worktree' then
        current.path = value
      elseif key == 'HEAD' then
        current.head = value
      elseif key == 'branch' then
        current.branch = value:match('refs/heads/(.+)') or value
      elseif key == 'bare' then
        current.bare = true
      elseif key == 'detached' then
        current.detached = true
      elseif key == 'locked' then
        current.locked = true
      elseif key == 'prunable' then
        current.prunable = true
      end
    end
  end

  if current.path then
    worktrees[#worktrees + 1] = current
  end

  return worktrees
end

function git_worktree.list(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local result, err = GitQueryBuilder(reponame):raw_args('worktree', 'list', '--porcelain'):execute()
  if err then return nil, err end

  return parse_porcelain(result or {})
end

function git_worktree.add(reponame, path, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not path then return nil, { 'path is required' } end

  opts = opts or {}
  local args = { 'worktree', 'add' }

  if opts.detach then
    args[#args + 1] = '--detach'
  end

  if opts.new_branch then
    args[#args + 1] = '-b'
    args[#args + 1] = opts.new_branch
  end

  args[#args + 1] = path

  if opts.branch then
    args[#args + 1] = opts.branch
  end

  return GitQueryBuilder(reponame):raw_args(unpack(args)):execute()
end

function git_worktree.remove(reponame, path, opts)
  if not reponame then return nil, { 'reponame is required' } end
  if not path then return nil, { 'path is required' } end

  opts = opts or {}
  local args = { 'worktree', 'remove' }

  if opts.force then
    args[#args + 1] = '--force'
  end

  args[#args + 1] = path

  return GitQueryBuilder(reponame):raw_args(unpack(args)):execute()
end

function git_worktree.prune(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('worktree', 'prune'):execute()
end

return git_worktree
