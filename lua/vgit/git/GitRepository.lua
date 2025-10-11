local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local git_status = require('vgit.git.git_status')
local git_remote = require('vgit.git.git_remote')
local git_merge = require('vgit.git.git_merge')
local git_rebase = require('vgit.git.git_rebase')
local git_cherry = require('vgit.git.git_cherry')
local git_revert = require('vgit.git.git_revert')
local git_bisect = require('vgit.git.git_bisect')
local git_submodule = require('vgit.git.git_submodule')

local GitRepository = Object:extend()

GitRepository.State = {
  UNINITIALIZED = 'uninitialized',
  VALID = 'valid',
  INVALID = 'invalid',
  BARE = 'bare',
}

function GitRepository:constructor(path)
  local repo = {
    _path = nil,
    _git_dir = nil,
    _state = GitRepository.State.UNINITIALIZED,
    _is_bare = false,
    _config = nil,

    _index = nil,
    _refs = nil,
    _remotes = nil,
    _submodules = nil,
  }

  if path then repo._path = path end

  return repo
end

function GitRepository.discover(path)
  local repo = GitRepository()
  local discovered_path, err = git_repo.discover(path)

  if err then
    repo._state = GitRepository.State.INVALID
    return nil, err
  end

  repo._path = discovered_path
  repo._state = GitRepository.State.VALID

  return repo, nil
end

function GitRepository.open(path)
  if not path then return nil, { 'path is required' } end

  local repo = GitRepository()
  local exists, err = git_repo.exists(path)

  if err then
    repo._state = GitRepository.State.INVALID
    return nil, err
  end

  if not exists then
    repo._state = GitRepository.State.INVALID
    return nil, { 'repository not found at: ' .. path }
  end

  repo._path = path
  repo._state = GitRepository.State.VALID

  return repo, nil
end

function GitRepository:is_valid()
  if self._state == GitRepository.State.UNINITIALIZED then self:_ensure_initialized() end
  return self._state == GitRepository.State.VALID
end

function GitRepository:is_bare()
  self:_ensure_initialized()
  return self._is_bare
end

function GitRepository:get_path()
  return self._path
end

function GitRepository:get_git_dir()
  if not self._git_dir then
    local dir, err = git_repo.dirname()
    if err then return nil, err end
    self._git_dir = dir
  end
  return self._git_dir, nil
end

function GitRepository:get_config()
  if not self._config then
    self:_ensure_initialized()
    local config, err = git_repo.config(self._path)
    if err then return nil, err end

    local parsed_config = {}
    for _, line in ipairs(config) do
      local key, value = line:match('([^=]+)=(.*)')
      if key and value then parsed_config[key] = value end
    end
    self._config = parsed_config
  end
  return self._config, nil
end

function GitRepository:status(filename)
  self:_ensure_initialized()
  return git_status.ls(self._path, filename)
end

function GitRepository:file_status(filename)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  return git_status.ls(self._path, filename)
end

function GitRepository:has_file(filename, commit)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local result, err = git_repo.has(self._path, filename, commit)
  if err then return nil, err end
  return result, nil
end

function GitRepository:is_ignored(filename)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local result, err = git_repo.ignores(self._path, filename)
  if err then return nil, err end
  return result, nil
end

function GitRepository:tree(commit)
  self:_ensure_initialized()

  local GitTree = require('vgit.git.GitTree')
  return GitTree(self, commit)
end

function GitRepository:index()
  self:_ensure_initialized()

  if not self._index then
    local GitIndex = require('vgit.git.GitIndex')
    self._index = GitIndex(self)
  end

  return self._index, nil
end

function GitRepository:refs()
  self:_ensure_initialized()

  if not self._refs then
    local GitRef = require('vgit.git.GitRef')
    self._refs = GitRef(self)
  end

  return self._refs, nil
end

function GitRepository:history(opts)
  self:_ensure_initialized()

  local GitHistory = require('vgit.git.GitHistory')
  return GitHistory(self, opts)
end

function GitRepository:working_tree()
  self:_ensure_initialized()

  local GitWorkingTree = require('vgit.git.GitWorkingTree')
  return GitWorkingTree(self)
end

-- Remote operations
function GitRepository:remotes()
  if self._remotes then return self._remotes, nil end

  self:_ensure_initialized()

  local remotes, err = git_remote.list(self._path, { verbose = true })
  if err then return nil, err end

  local GitRemote = require('vgit.git.GitRemote')
  local remote_objects = {}
  local remote_len = 0
  for _, remote in ipairs(remotes) do
    remote_len = remote_len + 1
    remote_objects[remote_len] = GitRemote(self, remote.name)
  end

  self._remotes = remote_objects
  return remote_objects, nil
end

function GitRepository:remote(name)
  if not name then return nil, { 'remote name is required' } end

  self:_ensure_initialized()

  local GitRemote = require('vgit.git.GitRemote')
  return GitRemote(self, name), nil
end

function GitRepository:add_remote(name, url, opts)
  if not name then return nil, { 'remote name is required' } end
  if not url then return nil, { 'url is required' } end

  self:_ensure_initialized()
  return git_remote.add(self._path, name, url, opts)
end

function GitRepository:remove_remote(name)
  if not name then return nil, { 'remote name is required' } end

  self:_ensure_initialized()
  return git_remote.remove(self._path, name)
end

-- Fetch from remotes
function GitRepository:fetch(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.fetch(self._path, remote, refspec, opts)
end

-- Push to remotes
function GitRepository:push(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.push(self._path, remote, refspec, opts)
end

-- Pull from remotes
function GitRepository:pull(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.pull(self._path, remote, refspec, opts)
end

-- Merge operations
function GitRepository:merge(commit, opts)
  if not commit then return nil, { 'commit/branch is required' } end

  self:_ensure_initialized()
  return git_merge.merge(self._path, commit, opts)
end

function GitRepository:merge_abort()
  self:_ensure_initialized()
  return git_merge.abort(self._path)
end

function GitRepository:merge_continue()
  self:_ensure_initialized()
  return git_merge.continue(self._path)
end

function GitRepository:merge_base(commit1, commit2)
  if not commit1 or not commit2 then return nil, { 'two commits are required' } end

  self:_ensure_initialized()
  return git_merge.base(self._path, commit1, commit2)
end

function GitRepository:is_ancestor(ancestor, descendant)
  if not ancestor or not descendant then return nil, { 'two commits are required' } end

  self:_ensure_initialized()
  return git_merge.is_ancestor(self._path, ancestor, descendant)
end

-- Rebase operations
function GitRepository:rebase(upstream, opts)
  if not upstream then return nil, { 'upstream is required' } end

  self:_ensure_initialized()
  return git_rebase.rebase(self._path, upstream, opts)
end

function GitRepository:rebase_continue()
  self:_ensure_initialized()
  return git_rebase.continue(self._path)
end

function GitRepository:rebase_skip()
  self:_ensure_initialized()
  return git_rebase.skip(self._path)
end

function GitRepository:rebase_abort()
  self:_ensure_initialized()
  return git_rebase.abort(self._path)
end

function GitRepository:rebase_status()
  self:_ensure_initialized()
  return git_rebase.status(self._path)
end

-- Cherry-pick operations
function GitRepository:cherry_pick(commits, opts)
  if not commits then return nil, { 'commits are required' } end

  self:_ensure_initialized()
  return git_cherry.pick(self._path, commits, opts)
end

function GitRepository:cherry_pick_continue()
  self:_ensure_initialized()
  return git_cherry.continue(self._path)
end

function GitRepository:cherry_pick_skip()
  self:_ensure_initialized()
  return git_cherry.skip(self._path)
end

function GitRepository:cherry_pick_abort()
  self:_ensure_initialized()
  return git_cherry.abort(self._path)
end

-- Revert operations
function GitRepository:revert(commits, opts)
  if not commits then return nil, { 'commits are required' } end

  self:_ensure_initialized()
  return git_revert.revert(self._path, commits, opts)
end

function GitRepository:revert_continue()
  self:_ensure_initialized()
  return git_revert.continue(self._path)
end

function GitRepository:revert_skip()
  self:_ensure_initialized()
  return git_revert.skip(self._path)
end

function GitRepository:revert_abort()
  self:_ensure_initialized()
  return git_revert.abort(self._path)
end

-- Bisect operations
function GitRepository:bisect_start(opts)
  self:_ensure_initialized()
  return git_bisect.start(self._path, opts)
end

function GitRepository:bisect_bad(commit)
  self:_ensure_initialized()
  return git_bisect.bad(self._path, commit)
end

function GitRepository:bisect_good(commits)
  self:_ensure_initialized()
  return git_bisect.good(self._path, commits)
end

function GitRepository:bisect_skip(commits)
  self:_ensure_initialized()
  return git_bisect.skip(self._path, commits)
end

function GitRepository:bisect_reset(commit)
  self:_ensure_initialized()
  return git_bisect.reset(self._path, commit)
end

function GitRepository:bisect_log()
  self:_ensure_initialized()
  return git_bisect.log(self._path)
end

function GitRepository:bisect_run(command, args)
  if not command then return nil, { 'command is required' } end

  self:_ensure_initialized()
  return git_bisect.run(self._path, command, args)
end

function GitRepository:bisect_status()
  self:_ensure_initialized()
  return git_bisect.status(self._path)
end

-- Submodule operations
function GitRepository:submodules()
  if self._submodules then return self._submodules, nil end

  self:_ensure_initialized()

  local submodules, err = git_submodule.list(self._path)
  if err then return nil, err end

  local GitSubmodule = require('vgit.git.GitSubmodule')
  local submodule_objects = {}
  local submodule_len = 0
  for _, submodule in ipairs(submodules) do
    submodule_len = submodule_len + 1
    submodule_objects[submodule_len] = GitSubmodule(self, submodule.path)
  end

  self._submodules = submodule_objects
  return submodule_objects, nil
end

function GitRepository:submodule(path)
  if not path then return nil, { 'submodule path is required' } end

  self:_ensure_initialized()

  local GitSubmodule = require('vgit.git.GitSubmodule')
  return GitSubmodule(self, path), nil
end

function GitRepository:add_submodule(url, path, opts)
  if not url then return nil, { 'url is required' } end
  if not path then return nil, { 'path is required' } end

  self:_ensure_initialized()
  return git_submodule.add(self._path, url, path, opts)
end

function GitRepository:update_submodules(paths, opts)
  self:_ensure_initialized()
  return git_submodule.update(self._path, paths, opts)
end

function GitRepository:sync_submodules(paths, opts)
  self:_ensure_initialized()
  return git_submodule.sync(self._path, paths, opts)
end

function GitRepository:submodule_foreach(command, opts)
  if not command then return nil, { 'command is required' } end

  self:_ensure_initialized()
  return git_submodule.foreach(self._path, command, opts)
end

-- File-level operations
function GitRepository:blame_file(filename, lnum)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local git_blame = require('vgit.git.git_blame')
  return git_blame.get(self._path, filename, lnum)
end

function GitRepository:file_content(filename, commit)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local GitBlob = require('vgit.git.GitBlob')
  local blob = GitBlob(self, filename, commit)
  return blob:content()
end

function GitRepository:file_lines(filename, commit)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local GitBlob = require('vgit.git.GitBlob')
  local blob = GitBlob(self, filename, commit)
  return blob:lines()
end

function GitRepository:has_file(filename, commit)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local git_repo_module = require('vgit.git.git_repo')
  return git_repo_module.has(self._path, filename, commit)
end

function GitRepository:file_status(filename)
  if not filename then return nil, { 'filename is required' } end
  self:_ensure_initialized()
  local git_status = require('vgit.git.git_status')
  return git_status.ls(self._path, filename)
end

-- Convenience staging methods (delegate to index)
function GitRepository:stage_file(filename)
  local index, err = self:index()
  if err then return nil, err end
  return index:add(filename)
end

function GitRepository:unstage_file(filename)
  local index, err = self:index()
  if err then return nil, err end
  return index:remove(filename)
end

function GitRepository:stage_hunk(filename, hunk)
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end
  local index, err = self:index()
  if err then return nil, err end
  return index:add_hunk(filename, hunk)
end

function GitRepository:unstage_hunk(filename, hunk)
  if not filename then return nil, { 'filename is required' } end
  if not hunk then return nil, { 'hunk is required' } end
  local index, err = self:index()
  if err then return nil, err end
  return index:remove_hunk(filename, hunk)
end

function GitRepository:reset()
  self._config = nil
  self._git_dir = nil
  self._index = nil
  self._refs = nil
  self._remotes = nil
  self._submodules = nil
end

function GitRepository:_ensure_initialized()
  if self._state ~= GitRepository.State.UNINITIALIZED then return end

  if not self._path then
    local discovered_path, err = git_repo.discover()
    if err then
      self._state = GitRepository.State.INVALID
      return
    end
    self._path = discovered_path
  end

  local exists, err = git_repo.exists(self._path)
  if err or not exists then
    self._state = GitRepository.State.INVALID
    return
  end

  self._state = GitRepository.State.VALID
end

return GitRepository
