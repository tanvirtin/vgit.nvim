local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local GitRef = lazy('vgit.git.GitRef')
local Object = lazy('vgit.core.Object')
local GitFile = lazy('vgit.git.GitFile')
local GitBlob = lazy('vgit.git.GitBlob')
local GitTree = lazy('vgit.git.GitTree')
local GitIndex = lazy('vgit.git.GitIndex')
local git_repo = lazy('vgit.git.git_repo')
local DiffBuilder = lazy('vgit.core.diff')
local git_merge = lazy('vgit.git.git_merge')
local assertion = lazy('vgit.core.assertion')
local git_status = lazy('vgit.git.git_status')
local git_remote = lazy('vgit.git.git_remote')
local git_rebase = lazy('vgit.git.git_rebase')
local git_cherry = lazy('vgit.git.git_cherry')
local git_revert = lazy('vgit.git.git_revert')
local git_bisect = lazy('vgit.git.git_bisect')
local GitHistory = lazy('vgit.git.GitHistory')
local git_log = lazy('vgit.git.git_log')
local git_show = lazy('vgit.git.git_show')
local git_stash = lazy('vgit.git.git_stash')
local git_blame_mod = lazy('vgit.git.git_blame')
local GitRemote_class = lazy('vgit.git.GitRemote')
local git_submodule = lazy('vgit.git.git_submodule')
local GitWorkingTree = lazy('vgit.git.GitWorkingTree')
local GitSubmodule_class = lazy('vgit.git.GitSubmodule')
local git_conflict_mod = lazy('vgit.libgit2.git_conflict')

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
    _state = GitRepository.State.UNINITIALIZED,
    _is_bare = false,
  }

  if path then repo._path = path end

  return repo
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

function GitRepository:is_ignored(filename)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local result, err = git_repo.ignores(self._path, filename)
  if err then return nil, err end
  return result, nil
end

function GitRepository:has_file(filename, commit)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  return git_repo.has(self._path, filename, commit)
end

function GitRepository:tree(commit)
  self:_ensure_initialized()

  return GitTree(self, commit)
end

function GitRepository:index()
  self:_ensure_initialized()
  return GitIndex(self), nil
end

function GitRepository:refs()
  self:_ensure_initialized()
  return GitRef(self), nil
end

function GitRepository:history(opts)
  self:_ensure_initialized()

  return GitHistory(self, opts)
end

function GitRepository:working_tree()
  self:_ensure_initialized()

  return GitWorkingTree(self)
end

function GitRepository:remotes()
  self:_ensure_initialized()

  local remotes, err = git_remote.list(self._path, { verbose = true })
  if err then return nil, err end

  local remote_objects = {}
  for i, remote in ipairs(remotes) do
    remote_objects[i] = GitRemote_class(self, remote.name)
  end

  return remote_objects, nil
end

function GitRepository:remote(name)
  assertion.assert(name, 'remote name is required')
  self:_ensure_initialized()
  return GitRemote_class(self, name), nil
end

function GitRepository:add_remote(name, url, opts)
  assertion.assert(name, 'remote name is required').assert(url, 'url is required')
  self:_ensure_initialized()
  return git_remote.add(self._path, name, url, opts)
end

function GitRepository:remove_remote(name)
  assertion.assert(name, 'remote name is required')
  self:_ensure_initialized()
  return git_remote.remove(self._path, name)
end

function GitRepository:fetch(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.fetch(self._path, remote, refspec, opts)
end

function GitRepository:push(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.push(self._path, remote, refspec, opts)
end

function GitRepository:pull(remote, refspec, opts)
  self:_ensure_initialized()
  return git_remote.pull(self._path, remote, refspec, opts)
end

function GitRepository:merge(commit, opts)
  assertion.assert(commit, 'commit/branch is required')
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
  assertion.assert(commit1, 'first commit is required').assert(commit2, 'second commit is required')
  self:_ensure_initialized()
  return git_merge.base(self._path, commit1, commit2)
end

function GitRepository:is_ancestor(ancestor, descendant)
  assertion.assert(ancestor, 'ancestor commit is required').assert(descendant, 'descendant commit is required')
  self:_ensure_initialized()
  return git_merge.is_ancestor(self._path, ancestor, descendant)
end

function GitRepository:rebase(upstream, opts)
  assertion.assert(upstream, 'upstream is required')
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

function GitRepository:cherry_pick(commits, opts)
  assertion.assert(commits, 'commits are required')
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

function GitRepository:revert(commits, opts)
  assertion.assert(commits, 'commits are required')
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

function GitRepository:cherry_pick_status()
  self:_ensure_initialized()
  return git_cherry.status(self._path)
end

function GitRepository:revert_status()
  self:_ensure_initialized()
  return git_revert.status(self._path)
end

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
  assertion.assert(command, 'command is required')
  self:_ensure_initialized()
  return git_bisect.run(self._path, command, args)
end

function GitRepository:bisect_status()
  self:_ensure_initialized()
  return git_bisect.status(self._path)
end

function GitRepository:submodules()
  self:_ensure_initialized()

  local submodules, err = git_submodule.list(self._path)
  if err then return nil, err end

  local submodule_objects = {}
  for i, submodule in ipairs(submodules) do
    submodule_objects[i] = GitSubmodule_class(self, submodule.path)
  end

  return submodule_objects, nil
end

function GitRepository:submodule(path)
  assertion.assert(path, 'submodule path is required')
  self:_ensure_initialized()
  return GitSubmodule_class(self, path), nil
end

function GitRepository:add_submodule(url, path, opts)
  assertion.assert(url, 'url is required').assert(path, 'path is required')
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
  assertion.assert(command, 'command is required')
  self:_ensure_initialized()
  return git_submodule.foreach(self._path, command, opts)
end

function GitRepository:blame_file(filename, lnum)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  return git_blame_mod.get(self._path, filename, lnum)
end

function GitRepository:blame_list(filename, commit)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  return git_blame_mod.list(self._path, filename, commit)
end

function GitRepository:file_content(filename, commit)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local blob = GitBlob(self, filename, commit)
  return blob:content()
end

function GitRepository:file_lines(filename, commit)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local blob = GitBlob(self, filename, commit)
  return blob:lines()
end

function GitRepository:stage_file(filename)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local index, err = self:index()
  if err then return nil, err end
  return index:add(filename)
end

function GitRepository:unstage_file(filename)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local index, err = self:index()
  if err then return nil, err end
  return index:remove(filename)
end

function GitRepository:stage_hunk(filename, hunk)
  assertion.assert(filename, 'filename is required').assert(hunk, 'hunk is required')
  local index, err = self:index()
  if err then return nil, err end
  return index:add_hunk(filename, hunk)
end

function GitRepository:unstage_hunk(filename, hunk)
  assertion.assert(filename, 'filename is required').assert(hunk, 'hunk is required')
  local index, err = self:index()
  if err then return nil, err end
  return index:remove_hunk(filename, hunk)
end

function GitRepository:reset_hunk(filename, hunk)
  assertion.assert(filename, 'filename is required').assert(hunk, 'hunk is required')
  self:_ensure_initialized()
  local git_file = GitFile(self._path .. '/' .. filename)
  return git_file:reset_hunk(hunk)
end

function GitRepository:commit(message)
  assertion.assert(message and message ~= '', 'commit message is required')
  local index, err = self:index()
  if err then return nil, err end
  return index:commit(message)
end

function GitRepository:reset(filename)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local working_tree = self:working_tree()
  return working_tree:reset(filename)
end

function GitRepository:stage_all()
  local index, err = self:index()
  if err then return nil, err end
  return index:add()
end

function GitRepository:unstage_all()
  local index, err = self:index()
  if err then return nil, err end
  return index:reset()
end

function GitRepository:status(opts)
  opts = opts or {}
  assertion.assert(self:is_valid(), 'Project has no .git folder')

  if opts.filename then
    self:_ensure_initialized()
    return git_status.ls(self._path, opts.filename)
  end

  local working_tree = self:working_tree()
  assertion.assert(working_tree, 'No working tree found')

  local statuses, err = working_tree:status()
  if err then return nil, err end

  local staged_files = {}
  local changed_files = {}
  local unmerged_files = {}

  utils.list.each(statuses, function(status)
    if status:is_unmerged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'unmerged' }
      table.insert(unmerged_files, data)
      return
    end

    if status:is_staged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'staged' }
      table.insert(staged_files, data)
    end

    if status:is_unstaged() then
      local id = utils.math.uuid()
      local data = { id = id, status = status, type = 'unstaged' }
      table.insert(changed_files, data)
    end
  end)

  local entries = {}
  if #unmerged_files ~= 0 then
    entries[#entries + 1] = {
      title = 'Merge Changes',
      entries = unmerged_files,
    }
  end
  if #staged_files ~= 0 then entries[#entries + 1] = {
    title = 'Staged Changes',
    entries = staged_files,
  } end
  if #changed_files ~= 0 then entries[#entries + 1] = {
    title = 'Changes',
    entries = changed_files,
  } end

  return {
    entries = entries,
    reponame = self:get_path(),
    layout_type = opts.layout_type or 'unified',
  }
end

function GitRepository:get_file_lines(filename, is_staged, git_file)
  if is_staged then return git_file:lines() end
  event.await()
  return fs.read_file(filename)
end

function GitRepository:show_lines(filename, commit)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  return git_show.lines(self._path, filename, commit)
end

function GitRepository:live_hunks(filename, current_lines)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  local git_file = GitFile(filename)
  return git_file:live_hunks(current_lines)
end

function GitRepository:log_get(commit)
  assertion.assert(commit, 'commit is required')
  self:_ensure_initialized()
  return git_log.get(self._path, commit)
end

function GitRepository:log_search(opts)
  self:_ensure_initialized()
  return git_log.list(self._path, opts)
end

function GitRepository:file_status(filename)
  assertion.assert(filename, 'filename is required')
  self:_ensure_initialized()
  return git_status.ls(self._path, filename)
end

function GitRepository:diff_tree(opts)
  self:_ensure_initialized()
  return git_status.tree(self._path, opts)
end

function GitRepository:stash_add()
  self:_ensure_initialized()
  return git_stash.add(self._path)
end

function GitRepository:stash_list(opts)
  self:_ensure_initialized()
  return git_stash.list(self._path, opts)
end

function GitRepository:stash_apply(stash_index)
  self:_ensure_initialized()
  return git_stash.apply(self._path, stash_index)
end

function GitRepository:stash_pop(stash_index)
  self:_ensure_initialized()
  return git_stash.pop(self._path, stash_index)
end

function GitRepository:stash_drop(stash_index)
  self:_ensure_initialized()
  return git_stash.drop(self._path, stash_index)
end

function GitRepository:stash_clear()
  self:_ensure_initialized()
  return git_stash.clear(self._path)
end

function GitRepository:conflict_status()
  return git_conflict_mod.status(self:get_path())
end

function GitRepository:diff(spec, opts)
  opts = opts or {}

  assertion.assert(spec, 'spec is required').assert(spec.type, 'type is required')

  local builder = DiffBuilder(self)
  local diff_spec = vim.tbl_extend('force', spec, opts)
  return builder:build(diff_spec)
end

return GitRepository
