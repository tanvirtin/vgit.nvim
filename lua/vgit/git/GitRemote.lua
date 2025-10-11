local Object = require('vgit.core.Object')
local git_remote = require('vgit.git.git_remote')

local GitRemote = Object:extend()

function GitRemote:constructor(repository, name)
  if not repository then error('GitRemote requires a repository') end

  local remote = {
    _repository = repository,
    _name = name,
    _url = nil,
    _push_url = nil,
    _info = nil,
  }

  return remote
end

function GitRemote:repository()
  return self._repository
end

function GitRemote:name()
  return self._name
end

-- Get fetch URL
function GitRemote:url()
  if not self._url then
    local url, err = git_remote.get_url(self._repository:get_path(), self._name)
    if err then return nil, err end
    self._url = url
  end
  return self._url, nil
end

-- Get push URL
function GitRemote:push_url()
  if not self._push_url then
    local url, err = git_remote.get_url(self._repository:get_path(), self._name, { push = true })
    if err then return nil, err end
    self._push_url = url
  end
  return self._push_url, nil
end

-- Set URL
function GitRemote:set_url(url, opts)
  if not url then return nil, { 'url is required' } end

  local _, err = git_remote.set_url(self._repository:get_path(), self._name, url, opts)
  if err then return nil, err end

  -- Clear cache
  if opts and opts.push then
    self._push_url = nil
  else
    self._url = nil
  end

  return true, nil
end

-- Get detailed information
function GitRemote:info()
  if not self._info then
    local info, err = git_remote.show(self._repository:get_path(), self._name)
    if err then return nil, err end
    self._info = info
  end
  return self._info, nil
end

-- Fetch from this remote
function GitRemote:fetch(refspec, opts)
  return git_remote.fetch(self._repository:get_path(), self._name, refspec, opts)
end

-- Push to this remote
function GitRemote:push(refspec, opts)
  return git_remote.push(self._repository:get_path(), self._name, refspec, opts)
end

-- Pull from this remote
function GitRemote:pull(refspec, opts)
  return git_remote.pull(self._repository:get_path(), self._name, refspec, opts)
end

-- Prune stale branches
function GitRemote:prune(opts)
  return git_remote.prune(self._repository:get_path(), self._name, opts)
end

-- Remove this remote
function GitRemote:remove()
  return git_remote.remove(self._repository:get_path(), self._name)
end

-- Rename this remote
function GitRemote:rename(new_name)
  if not new_name then return nil, { 'new name is required' } end

  local _, err = git_remote.rename(self._repository:get_path(), self._name, new_name)
  if err then return nil, err end

  self._name = new_name
  return true, nil
end

function GitRemote:reset_cache()
  self._url = nil
  self._push_url = nil
  self._info = nil
end

return GitRemote
