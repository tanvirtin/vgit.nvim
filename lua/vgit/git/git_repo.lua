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
  local search_dir = filepath

  -- If filepath is a file, get its directory
  if filepath then
    local stat = vim.loop.fs_stat(filepath)
    if stat and not stat.is_directory then
      search_dir = vim.fn.fnamemodify(filepath, ':p:h')
    else
      search_dir = vim.fn.fnamemodify(filepath, ':p')
    end
  else
    -- Use current directory if filepath is nil
    search_dir = vim.loop.cwd()
  end

  if discover_cache[search_dir] then return discover_cache[search_dir], nil end

  -- Use git -C to search for repo in the specified directory
  local system_result = vim.fn.system('git -C "' .. search_dir .. '" rev-parse --show-toplevel')
  local system_exit_code = vim.v.shell_error

  if system_exit_code == 0 and system_result and system_result ~= '' then
    local clean_result = system_result:gsub('\n', '')
    discover_cache[search_dir] = clean_result
    return clean_result, nil
  end

  return nil, { 'not a git repository' }
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
  -- Normalize 'index' to ':' for git reference
  if commit == 'index' then commit = ':' end

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
