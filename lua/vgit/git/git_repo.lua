local GitQueryBuilder = require('vgit.git.GitQueryBuilder')

local git_repo = {}

-- Cache: directory path -> repo root. Stable within a session; only stale if
-- user runs `git init` in a new location (rare, restart neovim to clear).
local discover_cache = {}

function git_repo.config(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return GitQueryBuilder(reponame):raw_args('config', '--list'):execute()
end

function git_repo.discover(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local result, err = GitQueryBuilder(dirname):raw_args('rev-parse', '--show-toplevel'):execute()

  local cached = discover_cache[dirname]
  if cached then return cached end

  local result, err = gitcli.run({ '-C', dirname, 'rev-parse', '--show-toplevel' })
  if err then return nil, err end
  if #result == 0 then return nil, { 'not a git repository' } end
  return result[1], nil
end

function git_repo.dirname()
  local reponame, err = git_repo.discover()
  if err then return nil, err end

  local result, git_dir_err = GitQueryBuilder(reponame):raw_args('rev-parse', '--git-dir'):execute()
  if git_dir_err then return nil, git_dir_err end
  if #result == 0 then return nil, { 'git directory not found' } end

  local git_dir = result[1]
  return reponame .. '/' .. git_dir, nil
end

function git_repo.exists(filepath)
  local dirname = (filepath and vim.fn.fnamemodify(filepath, ':p:h')) or vim.loop.cwd()
  local _, err = GitQueryBuilder(dirname):raw_args('rev-parse', '--is-inside-git-dir'):execute()

  return err == nil, nil
end

function git_repo.has(reponame, filename, commit)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  commit = commit or 'HEAD'

  local result, err =
    GitQueryBuilder(reponame):raw_args('--no-pager', 'ls-files', '--exclude-standard', commit, filename):execute()

  if err then return nil, err end
  return #result > 0, nil
end

function git_repo.ignores(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end
  if not filename then return nil, { 'filename is required' } end

  local result, err = GitQueryBuilder(reponame):raw_args('--no-pager', 'check-ignore', filename):execute()

  if err then return nil, err end
  return #result > 0, nil
end

function git_repo.checkout(reponame, name)
  if not reponame then return nil, { 'reponame is required' } end
  if not name then return nil, { 'name is required' } end
  return GitQueryBuilder(reponame):raw_args('--no-pager', 'checkout', '--quiet', name):execute()
end

function git_repo.reset(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  local _, err = GitQueryBuilder(reponame):raw_args('--no-pager', 'checkout', '-q', '--', filename or '.'):execute()
  if err then return nil, err end

  return GitQueryBuilder(reponame):raw_args('--no-pager', 'clean', '-fd', '--', filename or '.'):execute()
end

function git_repo.clean(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('--no-pager', 'clean', '-fd', '--', filename or '.'):execute()
end

return git_repo
