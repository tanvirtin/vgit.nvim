local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local git_repo = lazy('vgit.git.git_repo')
local GitRepository = lazy('vgit.git.GitRepository')

local _instances = {}
local _last = nil

local repository = {}

local function remember(repo)
  local path = repo:get_path()
  if not _instances[path] then _instances[path] = repo end
  _last = _instances[path]
  return _last
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

function repository.for_path(path)
  if not path or path == '' then return nil, { 'path is required' } end

  local absolute_path = vim.fn.fnamemodify(path, ':p')
  while not vim.uv.fs_stat(absolute_path) do
    local parent = vim.fn.fnamemodify(absolute_path, ':h')
    if parent == absolute_path then break end
    absolute_path = parent
  end

  return GitRepository.discover(absolute_path)
end

function repository.invalidate()
  _instances = {}
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
