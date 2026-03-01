local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local git_submodule = lazy('vgit.git.git_submodule')

local GitSubmodule = Object:extend()

function GitSubmodule:constructor(repository, path)
  if not repository then error('GitSubmodule requires a repository') end

  if not path then error('GitSubmodule requires a path') end

  local submodule = {
    ['$_repo_path'] = repository:get_path(),
    ['$_path'] = path,
    _info = nil,
  }

  return submodule
end

function GitSubmodule:path()
  return self._path
end

function GitSubmodule:info()
  if not self._info then
    local submodules, err = git_submodule.list(self._repo_path)
    if err then return nil, err end

    for _, submodule in ipairs(submodules) do
      if submodule.path == self._path then
        self._info = submodule
        break
      end
    end

    if not self._info then return nil, { 'submodule not found: ' .. self._path } end
  end

  return self._info, nil
end

function GitSubmodule:status()
  local info, err = self:info()
  if err then return nil, err end
  return info.status, nil
end

function GitSubmodule:hash()
  local info, err = self:info()
  if err then return nil, err end
  return info.hash, nil
end

function GitSubmodule:ref()
  local info, err = self:info()
  if err then return nil, err end
  return info.ref, nil
end

function GitSubmodule:init()
  local _, err = git_submodule.init(self._repo_path, self._path)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:deinit(opts)
  local _, err = git_submodule.deinit(self._repo_path, self._path, opts)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:update(opts)
  local _, err = git_submodule.update(self._repo_path, self._path, opts)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:sync(opts)
  local _, err = git_submodule.sync(self._repo_path, self._path, opts)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:set_branch(branch, opts)
  local _, err = git_submodule.set_branch(self._repo_path, branch, self._path, opts)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:set_url(url)
  if not url then return nil, { 'url is required' } end

  local _, err = git_submodule.set_url(self._repo_path, self._path, url)
  if err then return nil, err end

  self._info = nil
  return true, nil
end

function GitSubmodule:is_initialized()
  local status, err = self:status()
  if err then return false end
  return status ~= 'uninitialized'
end

function GitSubmodule:is_modified()
  local status, err = self:status()
  if err then return false end
  return status == 'modified'
end

function GitSubmodule:has_conflicts()
  local status, err = self:status()
  if err then return false end
  return status == 'conflicts'
end

function GitSubmodule:reset_cache()
  self._info = nil
end

return GitSubmodule
