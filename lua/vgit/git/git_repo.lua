local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local gitcli = lazy('vgit.git.gitcli')
local GitQueryBuilder = lazy('vgit.git.GitQueryBuilder')

local git_repo = {}

local discover_cache = {}

function git_repo.config(reponame)
  if not reponame then return nil, { 'reponame is required' } end
  return GitQueryBuilder(reponame):raw_args('config', '--list'):execute()
end

function git_repo.discover(filepath, opts)
  opts = opts or {}

  local search_dir

  if filepath then
    local stat = vim.loop.fs_stat(filepath)
    if stat and stat.type ~= 'directory' then
      search_dir = vim.fn.fnamemodify(filepath, ':p:h')
    else
      search_dir = vim.fn.fnamemodify(filepath, ':p')
    end
  else
    search_dir = vim.loop.cwd()
  end

  local cache_key = opts.git_dirname and (search_dir .. '#git_dir') or search_dir
  if discover_cache[cache_key] then return discover_cache[cache_key], nil end

  local result, err = gitcli.run({ '-C', search_dir, 'rev-parse', '--show-toplevel' })

  if err then return nil, { 'not a git repository' } end
  if not result or #result == 0 then return nil, { 'not a git repository' } end

  local clean_result = result[1]:gsub('\n', '')

  if opts.git_dirname then
    local git_dir, git_dir_err = git_repo.git_dir(clean_result)
    if git_dir_err or not git_dir then return nil, { 'git directory not found' } end
    discover_cache[cache_key] = git_dir
    return git_dir, nil
  end

  discover_cache[cache_key] = clean_result
  return clean_result, nil
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

function git_repo.git_dir(reponame)
  if not reponame then return nil, { 'reponame is required' } end

  local dot_git = reponame .. '/.git'
  if fs.is_dir(dot_git) then return dot_git end

  local lines = fs.read_file(dot_git)
  local gitdir = lines and lines[1] and lines[1]:match('^gitdir: (.+)$')
  if gitdir then return vim.uv.fs_realpath(fs.absolute_path(reponame, gitdir)) end

  local result, err = GitQueryBuilder(reponame):raw_args('rev-parse', '--git-dir'):execute()
  if err or #result == 0 then return nil, err or { 'git directory not found' } end

  local dir = result[1]
  if not vim.startswith(dir, '/') then dir = reponame .. '/' .. dir end
  return dir
end

function git_repo.branch(reponame)
  local git_dir, err = git_repo.git_dir(reponame)
  if not git_dir then return nil, err end

  local lines = fs.read_file(git_dir .. '/HEAD')
  local head = lines and lines[1]
  if not head then return nil, { 'HEAD not found' } end

  return head:match('^ref: refs/heads/(.+)$') or head:sub(1, 7), nil
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

  GitQueryBuilder(reponame):raw_args('--no-pager', 'checkout', '-q', '--', filename or '.'):execute()

  return GitQueryBuilder(reponame):raw_args('--no-pager', 'clean', '-fd', '--', filename or '.'):execute()
end

function git_repo.clean(reponame, filename)
  if not reponame then return nil, { 'reponame is required' } end

  return GitQueryBuilder(reponame):raw_args('--no-pager', 'clean', '-fd', '--', filename or '.'):execute()
end

function git_repo.clear_cache()
  discover_cache = {}
end

return git_repo
