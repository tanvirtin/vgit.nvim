local utils = require('tests.helpers.utils')

local World = {}
World.__index = World

function World.new()
  local root = utils.resolve_path(vim.fn.tempname())
  utils.mkdir_p(root)

  local env = {
    HOME = root .. '/home',
    GIT_CONFIG_GLOBAL = '/dev/null',
    GIT_CONFIG_SYSTEM = '/dev/null',
    GIT_AUTHOR_NAME = 'Scenario',
    GIT_AUTHOR_EMAIL = 'scenario@example.test',
    GIT_COMMITTER_NAME = 'Scenario',
    GIT_COMMITTER_EMAIL = 'scenario@example.test',
    GIT_AUTHOR_DATE = '2024-01-01T00:00:00Z',
    GIT_COMMITTER_DATE = '2024-01-01T00:00:00Z',
  }
  utils.mkdir_p(env.HOME)

  return setmetatable({ root = root, env = env }, World)
end

function World.numbered_lines(count, prefix)
  local lines = {}
  for i = 1, count do
    lines[i] = prefix .. i
  end
  return lines
end

function World:_git_command(dir, ...)
  local command = { 'env' }
  for key, value in pairs(self.env) do
    command[#command + 1] = key .. '=' .. value
  end
  vim.list_extend(command, { 'git', '-C', dir, ... })
  return command
end

function World:git(dir, ...)
  local out, err = utils.git_exec(self:_git_command(dir, ...), { check = true })
  if err then error(err, 2) end
  return (out:gsub('\n+$', ''))
end

-- Like git(), but returns the output (or the error text) instead of raising, so
-- failure reports and negative assertions can inspect a failing command.
function World:git_try(dir, ...)
  local out = utils.git_exec(self:_git_command(dir, ...))
  return ((out or ''):gsub('\n+$', ''))
end

function World:write(path, lines)
  utils.mkdir_p(vim.fn.fnamemodify(path, ':h'))
  vim.fn.writefile(type(lines) == 'table' and lines or { lines }, path)
  return path
end

function World:repo(name, files)
  local dir = self.root .. '/' .. name
  utils.mkdir_p(dir)
  self:git(dir, 'init', '-q')
  self:git(dir, 'config', 'user.name', 'Scenario')
  self:git(dir, 'config', 'user.email', 'scenario@example.test')

  for filename, lines in pairs(files or {}) do
    self:write(dir .. '/' .. filename, lines)
  end

  self:git(dir, 'add', '-A')
  self:git(dir, 'commit', '-q', '--allow-empty', '-m', 'initial')

  return utils.resolve_path(dir)
end

function World:worktree(repo, branch, opts)
  opts = opts or {}
  local dir = opts.path or (self.root .. '/' .. branch)
  self:git(repo, 'worktree', 'add', '-q', '-b', branch, dir, opts.from or 'HEAD')
  return utils.resolve_path(dir)
end

function World:commit(dir, message)
  self:git(dir, 'add', '-A')
  self:git(dir, 'commit', '-q', '-m', message)
end

-- Builds linear history on top of the repo's initial commit. Each entry is
-- `{ message = '...', files = { path = lines } }`.
function World:history(dir, commits)
  for _, entry in ipairs(commits) do
    for path, lines in pairs(entry.files or {}) do
      self:write(dir .. '/' .. path, lines)
    end
    self:commit(dir, entry.message)
  end
end

function World:branch(dir, name, opts)
  opts = opts or {}
  self:git(dir, 'branch', name, opts.from or 'HEAD')
  if opts.checkout then self:git(dir, 'checkout', '-q', name) end
  return name
end

-- Leaves `dir` mid-merge with a real conflict on `path`: both sides change the
-- same line differently. The repo must already contain `path` committed.
function World:conflict(dir, path, ours, theirs)
  local base = self:git(dir, 'rev-parse', '--abbrev-ref', 'HEAD')
  self:git(dir, 'checkout', '-q', '-b', 'conflicting')
  self:write(dir .. '/' .. path, theirs)
  self:commit(dir, 'their change')
  self:git(dir, 'checkout', '-q', base)
  self:write(dir .. '/' .. path, ours)
  self:commit(dir, 'our change')
  self:git_try(dir, 'merge', 'conflicting')
end

function World:stash(dir, message)
  self:git(dir, 'stash', 'push', '--include-untracked', '-m', message)
end

function World:teardown()
  utils.rmdir_recursive(self.root)
end

return World
