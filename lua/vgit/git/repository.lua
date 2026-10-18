local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local git_repo = lazy('vgit.git.git_repo')
local GitRepository = lazy('vgit.git.GitRepository')

local _instance = nil

local repository = {}

function repository.current()
  if not _instance then
    local repo, err = GitRepository.discover()
    if err then return nil, err end
    _instance = repo
  end
  return _instance, nil
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
  _instance = nil
end

function repository.switch(path)
  repository.invalidate()
  git_repo.clear_cache()
  fs.chdir(path)
end

function repository.is_loaded()
  return _instance ~= nil
end

function repository.get_cached()
  return _instance
end

return repository
