local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local git_repo = lazy('vgit.git.git_repo')
local GitRepository = lazy('vgit.git.GitRepository')

local IGNORED_FOLDERS = { ['.git'] = true, node_modules = true }

local _instances = {}
local _by_git_dir = {}
local _last = nil

local repository = {}

local function intern(repo)
  local path = repo:get_path()
  if not _instances[path] then
    _instances[path] = repo
    local git_dir = git_repo.git_dir(path)
    if git_dir then _by_git_dir[git_dir] = repo end
    event.watch(git_dir)
  end
  return _instances[path]
end

local function remember(repo)
  _last = intern(repo)
  return _last
end

local function child_repos(dirname)
  local repos = {}
  for name, type in vim.fs.dir(dirname) do
    local path = dirname .. '/' .. name
    if type == 'directory' and not IGNORED_FOLDERS[name] and fs.exists(path .. '/.git') then
      repos[#repos + 1] = GitRepository.at(vim.uv.fs_realpath(path))
    end
  end
  return repos
end

local function current_filepath()
  if vim.in_fast_event() then return nil end
  if vim.bo.buftype ~= '' then return nil end
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then return nil end
  return name
end

function repository.current()
  local filepath = current_filepath()
  if filepath then
    local repo = repository.for_path(filepath)
    if repo then return remember(repo), nil end
  end

  local repo, err = GitRepository.discover()
  if err then return nil, err end
  return remember(repo), nil
end

function repository.list()
  local repos = {}
  local seen = {}

  local function add(repo)
    if not repo then return end
    repo = intern(repo)
    local path = repo:get_path()
    if seen[path] then return end
    seen[path] = true
    repos[#repos + 1] = repo
  end

  local filepath = current_filepath()
  if filepath then add(repository.for_path(filepath)) end

  local cwd = vim.uv.cwd()
  add(GitRepository.discover(cwd))
  for _, repo in ipairs(child_repos(cwd)) do
    add(repo)
  end

  table.sort(repos, function(a, b)
    return a:get_path() < b:get_path()
  end)

  return repos
end

function repository.for_git_dir(git_dir)
  return _by_git_dir[git_dir]
end

function repository.for_path(path)
  if not path or path == '' then return nil, { 'path is required' } end

  local absolute_path = vim.fn.fnamemodify(path, ':p')
  while not vim.uv.fs_stat(absolute_path) do
    local parent = vim.fn.fnamemodify(absolute_path, ':h')
    if parent == absolute_path then break end
    absolute_path = parent
  end

  local repo, err = GitRepository.discover(absolute_path)
  if err then return nil, err end
  return intern(repo), nil
end

function repository.invalidate()
  _instances = {}
  _by_git_dir = {}
  _last = nil
end

function repository.switch(path)
  repository.invalidate()
  git_repo.clear_cache()
  fs.chdir(path)
end

function repository.is_loaded()
  return _last ~= nil
end

function repository.get_cached()
  return _last
end

return repository
