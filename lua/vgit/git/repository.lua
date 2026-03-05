local lazy = require('vgit.core.lazy')

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

function repository.invalidate()
  _instance = nil
end

function repository.is_loaded()
  return _instance ~= nil
end

function repository.get_cached()
  return _instance
end

return repository
