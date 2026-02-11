-- Stubs must be injected BEFORE requiring GitRepository.

local git_repo_stub = {}
local git_merge_stub = {}
local git_status_stub = {}
local git_remote_stub = {}
local git_rebase_stub = {}
local git_cherry_stub = {}
local git_revert_stub = {}
local git_bisect_stub = {}
local git_submodule_stub = {}
local event_stub = { await = function() end }

package.loaded['vgit.git.git_repo'] = git_repo_stub
package.loaded['vgit.git.git_merge'] = git_merge_stub
package.loaded['vgit.git.git_status'] = git_status_stub
package.loaded['vgit.git.git_remote'] = git_remote_stub
package.loaded['vgit.git.git_rebase'] = git_rebase_stub
package.loaded['vgit.git.git_cherry'] = git_cherry_stub
package.loaded['vgit.git.git_revert'] = git_revert_stub
package.loaded['vgit.git.git_bisect'] = git_bisect_stub
package.loaded['vgit.git.git_submodule'] = git_submodule_stub
package.loaded['vgit.core.event'] = event_stub

local GitRepository = require('vgit.git.GitRepository')

local eq = assert.are.same

-- Helper to make a VALID GitRepository with a given path, bypassing _ensure_initialized.
local function make_valid_repo(path)
  local repo = GitRepository()
  repo._path = path
  repo._state = GitRepository.State.VALID
  return repo
end

-- Helper to reset all stubs to default no-op functions before each test.
local function reset_stubs()
  -- git_repo
  git_repo_stub.discover = function() return '/mock/repo', nil end
  git_repo_stub.exists = function() return true, nil end
  git_repo_stub.ignores = function() return false, nil end
  git_repo_stub.has = function() return true, nil end

  -- git_merge
  git_merge_stub.merge = function() return {}, nil end
  git_merge_stub.abort = function() return {}, nil end
  git_merge_stub.continue = function() return {}, nil end
  git_merge_stub.base = function() return 'abc123', nil end
  git_merge_stub.is_ancestor = function() return true end

  -- git_status
  git_status_stub.ls = function() return {}, nil end

  -- git_remote
  git_remote_stub.list = function() return {}, nil end
  git_remote_stub.add = function() return {}, nil end
  git_remote_stub.remove = function() return {}, nil end
  git_remote_stub.fetch = function() return {}, nil end
  git_remote_stub.push = function() return {}, nil end
  git_remote_stub.pull = function() return {}, nil end

  -- git_rebase
  git_rebase_stub.rebase = function() return {}, nil end
  git_rebase_stub.continue = function() return {}, nil end
  git_rebase_stub.skip = function() return {}, nil end
  git_rebase_stub.abort = function() return {}, nil end
  git_rebase_stub.status = function() return {}, nil end

  -- git_cherry
  git_cherry_stub.pick = function() return {}, nil end
  git_cherry_stub.continue = function() return {}, nil end
  git_cherry_stub.skip = function() return {}, nil end
  git_cherry_stub.abort = function() return {}, nil end
  git_cherry_stub.status = function() return {}, nil end

  -- git_revert
  git_revert_stub.revert = function() return {}, nil end
  git_revert_stub.continue = function() return {}, nil end
  git_revert_stub.skip = function() return {}, nil end
  git_revert_stub.abort = function() return {}, nil end
  git_revert_stub.status = function() return {}, nil end

  -- git_bisect
  git_bisect_stub.start = function() return {}, nil end
  git_bisect_stub.bad = function() return {}, nil end
  git_bisect_stub.good = function() return {}, nil end
  git_bisect_stub.skip = function() return {}, nil end
  git_bisect_stub.reset = function() return {}, nil end
  git_bisect_stub.log = function() return {}, nil end
  git_bisect_stub.run = function() return {}, nil end
  git_bisect_stub.status = function() return {}, nil end

  -- git_submodule
  git_submodule_stub.list = function() return {}, nil end
  git_submodule_stub.add = function() return {}, nil end
  git_submodule_stub.update = function() return {}, nil end
  git_submodule_stub.sync = function() return {}, nil end
  git_submodule_stub.foreach = function() return {}, nil end
end

describe('GitRepository', function()
  before_each(function()
    reset_stubs()
  end)

  describe('State enum', function()
    it('should define UNINITIALIZED constant', function()
      assert.are.equal('uninitialized', GitRepository.State.UNINITIALIZED)
    end)

    it('should define VALID constant', function()
      assert.are.equal('valid', GitRepository.State.VALID)
    end)

    it('should define INVALID constant', function()
      assert.are.equal('invalid', GitRepository.State.INVALID)
    end)

    it('should define BARE constant', function()
      assert.are.equal('bare', GitRepository.State.BARE)
    end)
  end)

  describe('constructor', function()
    it('should create a repository with UNINITIALIZED state and nil path by default', function()
      local repo = GitRepository()
      assert.are.equal(GitRepository.State.UNINITIALIZED, repo._state)
      assert.is_nil(repo._path)
      assert.is_false(repo._is_bare)
    end)

    it('should create a repository with provided path', function()
      local repo = GitRepository('/some/path')
      assert.are.equal(GitRepository.State.UNINITIALIZED, repo._state)
      assert.are.equal('/some/path', repo._path)
    end)
  end)

  describe('_ensure_initialized', function()
    it('should call discover and set VALID when no path and discover succeeds', function()
      local discover_called = false
      git_repo_stub.discover = function()
        discover_called = true
        return '/discovered/repo', nil
      end
      git_repo_stub.exists = function() return true, nil end

      local repo = GitRepository()
      repo:_ensure_initialized()

      assert.is_true(discover_called)
      assert.are.equal(GitRepository.State.VALID, repo._state)
      assert.are.equal('/discovered/repo', repo._path)
    end)

    it('should set INVALID when no path and discover fails', function()
      git_repo_stub.discover = function()
        return nil, { 'not a git repository' }
      end

      local repo = GitRepository()
      repo:_ensure_initialized()

      assert.are.equal(GitRepository.State.INVALID, repo._state)
      assert.is_nil(repo._path)
    end)

    it('should call exists and set VALID when path is provided and exists succeeds', function()
      local exists_path = nil
      git_repo_stub.exists = function(path)
        exists_path = path
        return true, nil
      end

      local repo = GitRepository('/my/repo')
      repo:_ensure_initialized()

      assert.are.equal('/my/repo', exists_path)
      assert.are.equal(GitRepository.State.VALID, repo._state)
    end)

    it('should set INVALID when path is provided and exists returns error', function()
      git_repo_stub.exists = function()
        return nil, { 'some error' }
      end

      local repo = GitRepository('/my/repo')
      repo:_ensure_initialized()

      assert.are.equal(GitRepository.State.INVALID, repo._state)
    end)

    it('should set INVALID when path is provided and exists returns false', function()
      git_repo_stub.exists = function()
        return false, nil
      end

      local repo = GitRepository('/my/repo')
      repo:_ensure_initialized()

      assert.are.equal(GitRepository.State.INVALID, repo._state)
    end)

    it('should NOT re-call discover or exists when already VALID', function()
      local call_count = 0
      git_repo_stub.discover = function()
        call_count = call_count + 1
        return '/discovered', nil
      end
      git_repo_stub.exists = function()
        call_count = call_count + 1
        return true, nil
      end

      local repo = make_valid_repo('/repo')
      repo:_ensure_initialized()

      assert.are.equal(0, call_count)
      assert.are.equal(GitRepository.State.VALID, repo._state)
    end)

    it('should NOT re-call discover or exists when already INVALID', function()
      local call_count = 0
      git_repo_stub.discover = function()
        call_count = call_count + 1
        return '/discovered', nil
      end
      git_repo_stub.exists = function()
        call_count = call_count + 1
        return true, nil
      end

      local repo = GitRepository()
      repo._state = GitRepository.State.INVALID
      repo:_ensure_initialized()

      assert.are.equal(0, call_count)
      assert.are.equal(GitRepository.State.INVALID, repo._state)
    end)
  end)

  describe('GitRepository.discover (static)', function()
    it('should return a VALID repo on success', function()
      git_repo_stub.discover = function(path)
        return '/found/repo', nil
      end

      local repo, err = GitRepository.discover('/some/path')

      assert.is_nil(err)
      assert.is_not_nil(repo)
      assert.are.equal(GitRepository.State.VALID, repo._state)
      assert.are.equal('/found/repo', repo._path)
    end)

    it('should return nil and error on failure', function()
      git_repo_stub.discover = function()
        return nil, { 'not a git repository' }
      end

      local repo, err = GitRepository.discover('/some/path')

      assert.is_nil(repo)
      assert.is_not_nil(err)
      eq({ 'not a git repository' }, err)
    end)
  end)

  describe('GitRepository.open (static)', function()
    it('should return a VALID repo when path exists', function()
      git_repo_stub.exists = function()
        return true, nil
      end

      local repo, err = GitRepository.open('/my/repo')

      assert.is_nil(err)
      assert.is_not_nil(repo)
      assert.are.equal(GitRepository.State.VALID, repo._state)
      assert.are.equal('/my/repo', repo._path)
    end)

    it('should return nil and error when exists returns error', function()
      git_repo_stub.exists = function()
        return nil, { 'some error' }
      end

      local repo, err = GitRepository.open('/my/repo')

      assert.is_nil(repo)
      assert.is_not_nil(err)
      eq({ 'some error' }, err)
    end)

    it('should return nil and error when path does not exist', function()
      git_repo_stub.exists = function()
        return false, nil
      end

      local repo, err = GitRepository.open('/my/repo')

      assert.is_nil(repo)
      assert.is_not_nil(err)
      eq({ 'repository not found at: /my/repo' }, err)
    end)

    it('should return nil and error when path is nil', function()
      local repo, err = GitRepository.open(nil)

      assert.is_nil(repo)
      assert.is_not_nil(err)
      eq({ 'path is required' }, err)
    end)
  end)

  describe('is_valid', function()
    it('should return true when state is VALID', function()
      local repo = make_valid_repo('/repo')
      assert.is_true(repo:is_valid())
    end)

    it('should return false when state is INVALID', function()
      local repo = GitRepository()
      repo._state = GitRepository.State.INVALID
      assert.is_false(repo:is_valid())
    end)

    it('should trigger _ensure_initialized when UNINITIALIZED', function()
      git_repo_stub.discover = function()
        return '/discovered', nil
      end
      git_repo_stub.exists = function()
        return true, nil
      end

      local repo = GitRepository()
      assert.are.equal(GitRepository.State.UNINITIALIZED, repo._state)

      local result = repo:is_valid()

      assert.is_true(result)
      assert.are.equal(GitRepository.State.VALID, repo._state)
    end)

    it('should return false after _ensure_initialized fails', function()
      git_repo_stub.discover = function()
        return nil, { 'no repo' }
      end

      local repo = GitRepository()
      local result = repo:is_valid()

      assert.is_false(result)
      assert.are.equal(GitRepository.State.INVALID, repo._state)
    end)
  end)

  describe('get_path', function()
    it('should return stored path', function()
      local repo = make_valid_repo('/my/repo')
      assert.are.equal('/my/repo', repo:get_path())
    end)

    it('should return nil when no path set', function()
      local repo = GitRepository()
      repo._state = GitRepository.State.INVALID
      assert.is_nil(repo:get_path())
    end)
  end)

  describe('is_ignored', function()
    it('should throw when filename is nil', function()
      local repo = make_valid_repo('/repo')
      assert.has_error(function()
        repo:is_ignored(nil)
      end)
    end)

    it('should delegate to git_repo.ignores', function()
      local captured_path, captured_filename
      git_repo_stub.ignores = function(path, filename)
        captured_path = path
        captured_filename = filename
        return true, nil
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:is_ignored('foo.txt')

      assert.is_nil(err)
      assert.is_true(result)
      assert.are.equal('/repo', captured_path)
      assert.are.equal('foo.txt', captured_filename)
    end)

    it('should return error from git_repo.ignores', function()
      git_repo_stub.ignores = function()
        return nil, { 'ignores error' }
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:is_ignored('foo.txt')

      assert.is_nil(result)
      eq({ 'ignores error' }, err)
    end)
  end)

  describe('has_file', function()
    it('should throw when filename is nil', function()
      local repo = make_valid_repo('/repo')
      assert.has_error(function()
        repo:has_file(nil)
      end)
    end)

    it('should delegate to git_repo.has', function()
      local captured_path, captured_filename, captured_commit
      git_repo_stub.has = function(path, filename, commit)
        captured_path = path
        captured_filename = filename
        captured_commit = commit
        return true, nil
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:has_file('bar.txt', 'HEAD')

      assert.is_nil(err)
      assert.is_true(result)
      assert.are.equal('/repo', captured_path)
      assert.are.equal('bar.txt', captured_filename)
      assert.are.equal('HEAD', captured_commit)
    end)
  end)

  describe('assertion validation on methods', function()
    local repo

    before_each(function()
      repo = make_valid_repo('/repo')
    end)

    it('merge requires commit', function()
      assert.has_error(function()
        repo:merge(nil)
      end)
    end)

    it('merge_base requires first commit', function()
      assert.has_error(function()
        repo:merge_base(nil, 'abc')
      end)
    end)

    it('merge_base requires second commit', function()
      assert.has_error(function()
        repo:merge_base('abc', nil)
      end)
    end)

    it('is_ancestor requires ancestor', function()
      assert.has_error(function()
        repo:is_ancestor(nil, 'desc')
      end)
    end)

    it('is_ancestor requires descendant', function()
      assert.has_error(function()
        repo:is_ancestor('anc', nil)
      end)
    end)

    it('rebase requires upstream', function()
      assert.has_error(function()
        repo:rebase(nil)
      end)
    end)

    it('cherry_pick requires commits', function()
      assert.has_error(function()
        repo:cherry_pick(nil)
      end)
    end)

    it('revert requires commits', function()
      assert.has_error(function()
        repo:revert(nil)
      end)
    end)

    it('bisect_run requires command', function()
      assert.has_error(function()
        repo:bisect_run(nil)
      end)
    end)

    it('remote requires name', function()
      assert.has_error(function()
        repo:remote(nil)
      end)
    end)

    it('add_remote requires name', function()
      assert.has_error(function()
        repo:add_remote(nil, 'http://url')
      end)
    end)

    it('add_remote requires url', function()
      assert.has_error(function()
        repo:add_remote('origin', nil)
      end)
    end)

    it('remove_remote requires name', function()
      assert.has_error(function()
        repo:remove_remote(nil)
      end)
    end)

    it('blame_file requires filename', function()
      -- Stub the lazy require for git_blame
      package.loaded['vgit.git.git_blame'] = { get = function() return {}, nil end }

      assert.has_error(function()
        repo:blame_file(nil)
      end)

      package.loaded['vgit.git.git_blame'] = nil
    end)

    it('file_content requires filename', function()
      assert.has_error(function()
        repo:file_content(nil)
      end)
    end)

    it('file_lines requires filename', function()
      assert.has_error(function()
        repo:file_lines(nil)
      end)
    end)

    it('stage_file requires filename', function()
      assert.has_error(function()
        repo:stage_file(nil)
      end)
    end)

    it('unstage_file requires filename', function()
      assert.has_error(function()
        repo:unstage_file(nil)
      end)
    end)

    it('stage_hunk requires filename', function()
      assert.has_error(function()
        repo:stage_hunk(nil, { start = 1 })
      end)
    end)

    it('stage_hunk requires hunk', function()
      assert.has_error(function()
        repo:stage_hunk('file.txt', nil)
      end)
    end)

    it('unstage_hunk requires filename', function()
      assert.has_error(function()
        repo:unstage_hunk(nil, { start = 1 })
      end)
    end)

    it('unstage_hunk requires hunk', function()
      assert.has_error(function()
        repo:unstage_hunk('file.txt', nil)
      end)
    end)

    it('reset_hunk requires filename', function()
      assert.has_error(function()
        repo:reset_hunk(nil, { start = 1 })
      end)
    end)

    it('reset_hunk requires hunk', function()
      assert.has_error(function()
        repo:reset_hunk('file.txt', nil)
      end)
    end)

    it('commit requires non-empty message', function()
      assert.has_error(function()
        repo:commit(nil)
      end)
      assert.has_error(function()
        repo:commit('')
      end)
    end)

    it('reset requires filename', function()
      assert.has_error(function()
        repo:reset(nil)
      end)
    end)

    it('submodule requires path', function()
      assert.has_error(function()
        repo:submodule(nil)
      end)
    end)

    it('add_submodule requires url', function()
      assert.has_error(function()
        repo:add_submodule(nil, '/path')
      end)
    end)

    it('add_submodule requires path', function()
      assert.has_error(function()
        repo:add_submodule('http://url', nil)
      end)
    end)

    it('submodule_foreach requires command', function()
      assert.has_error(function()
        repo:submodule_foreach(nil)
      end)
    end)
  end)

  describe('delegation tests', function()
    local repo

    before_each(function()
      repo = make_valid_repo('/repo')
    end)

    -- Merge delegation
    describe('merge', function()
      it('should delegate to git_merge.merge with correct args', function()
        local captured = {}
        git_merge_stub.merge = function(path, commit, opts)
          captured = { path = path, commit = commit, opts = opts }
          return { 'ok' }, nil
        end

        local result, err = repo:merge('feature', { no_ff = true })

        assert.is_nil(err)
        eq({ 'ok' }, result)
        assert.are.equal('/repo', captured.path)
        assert.are.equal('feature', captured.commit)
        eq({ no_ff = true }, captured.opts)
      end)
    end)

    describe('merge_abort', function()
      it('should delegate to git_merge.abort', function()
        local captured_path
        git_merge_stub.abort = function(path)
          captured_path = path
          return { 'aborted' }, nil
        end

        local result, err = repo:merge_abort()

        assert.is_nil(err)
        eq({ 'aborted' }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('merge_continue', function()
      it('should delegate to git_merge.continue', function()
        local captured_path
        git_merge_stub.continue = function(path)
          captured_path = path
          return {}, nil
        end

        local _, err = repo:merge_continue()
        assert.is_nil(err)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('merge_base', function()
      it('should delegate to git_merge.base with correct args', function()
        local captured = {}
        git_merge_stub.base = function(path, c1, c2)
          captured = { path = path, c1 = c1, c2 = c2 }
          return 'basecommit', nil
        end

        local result, err = repo:merge_base('abc', 'def')

        assert.is_nil(err)
        assert.are.equal('basecommit', result)
        assert.are.equal('/repo', captured.path)
        assert.are.equal('abc', captured.c1)
        assert.are.equal('def', captured.c2)
      end)
    end)

    describe('is_ancestor', function()
      it('should delegate to git_merge.is_ancestor', function()
        local captured = {}
        git_merge_stub.is_ancestor = function(path, ancestor, descendant)
          captured = { path = path, ancestor = ancestor, descendant = descendant }
          return true
        end

        local result = repo:is_ancestor('anc', 'desc')

        assert.is_true(result)
        assert.are.equal('/repo', captured.path)
        assert.are.equal('anc', captured.ancestor)
        assert.are.equal('desc', captured.descendant)
      end)
    end)

    -- Rebase delegation
    describe('rebase', function()
      it('should delegate to git_rebase.rebase', function()
        local captured = {}
        git_rebase_stub.rebase = function(path, upstream, opts)
          captured = { path = path, upstream = upstream, opts = opts }
          return {}, nil
        end

        repo:rebase('main', { interactive = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('main', captured.upstream)
        eq({ interactive = true }, captured.opts)
      end)
    end)

    describe('rebase_continue', function()
      it('should delegate to git_rebase.continue', function()
        local captured_path
        git_rebase_stub.continue = function(path)
          captured_path = path
          return {}, nil
        end

        repo:rebase_continue()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('rebase_skip', function()
      it('should delegate to git_rebase.skip', function()
        local captured_path
        git_rebase_stub.skip = function(path)
          captured_path = path
          return {}, nil
        end

        repo:rebase_skip()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('rebase_abort', function()
      it('should delegate to git_rebase.abort', function()
        local captured_path
        git_rebase_stub.abort = function(path)
          captured_path = path
          return {}, nil
        end

        repo:rebase_abort()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('rebase_status', function()
      it('should delegate to git_rebase.status', function()
        local captured_path
        git_rebase_stub.status = function(path)
          captured_path = path
          return { in_progress = true }, nil
        end

        local result, err = repo:rebase_status()
        assert.is_nil(err)
        eq({ in_progress = true }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    -- Cherry-pick delegation
    describe('cherry_pick', function()
      it('should delegate to git_cherry.pick', function()
        local captured = {}
        git_cherry_stub.pick = function(path, commits, opts)
          captured = { path = path, commits = commits, opts = opts }
          return {}, nil
        end

        repo:cherry_pick({ 'abc123' }, { no_commit = true })

        assert.are.equal('/repo', captured.path)
        eq({ 'abc123' }, captured.commits)
        eq({ no_commit = true }, captured.opts)
      end)
    end)

    describe('cherry_pick_continue', function()
      it('should delegate to git_cherry.continue', function()
        local captured_path
        git_cherry_stub.continue = function(path)
          captured_path = path
          return {}, nil
        end

        repo:cherry_pick_continue()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('cherry_pick_skip', function()
      it('should delegate to git_cherry.skip', function()
        local captured_path
        git_cherry_stub.skip = function(path)
          captured_path = path
          return {}, nil
        end

        repo:cherry_pick_skip()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('cherry_pick_abort', function()
      it('should delegate to git_cherry.abort', function()
        local captured_path
        git_cherry_stub.abort = function(path)
          captured_path = path
          return {}, nil
        end

        repo:cherry_pick_abort()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('cherry_pick_status', function()
      it('should delegate to git_cherry.status', function()
        local captured_path
        git_cherry_stub.status = function(path)
          captured_path = path
          return { in_progress = false }, nil
        end

        local result = repo:cherry_pick_status()
        eq({ in_progress = false }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    -- Revert delegation
    describe('revert', function()
      it('should delegate to git_revert.revert', function()
        local captured = {}
        git_revert_stub.revert = function(path, commits, opts)
          captured = { path = path, commits = commits, opts = opts }
          return {}, nil
        end

        repo:revert({ 'abc' }, { no_commit = true })

        assert.are.equal('/repo', captured.path)
        eq({ 'abc' }, captured.commits)
        eq({ no_commit = true }, captured.opts)
      end)
    end)

    describe('revert_continue', function()
      it('should delegate to git_revert.continue', function()
        local captured_path
        git_revert_stub.continue = function(path)
          captured_path = path
          return {}, nil
        end

        repo:revert_continue()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('revert_skip', function()
      it('should delegate to git_revert.skip', function()
        local captured_path
        git_revert_stub.skip = function(path)
          captured_path = path
          return {}, nil
        end

        repo:revert_skip()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('revert_abort', function()
      it('should delegate to git_revert.abort', function()
        local captured_path
        git_revert_stub.abort = function(path)
          captured_path = path
          return {}, nil
        end

        repo:revert_abort()
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('revert_status', function()
      it('should delegate to git_revert.status', function()
        local captured_path
        git_revert_stub.status = function(path)
          captured_path = path
          return { in_progress = true }, nil
        end

        local result = repo:revert_status()
        eq({ in_progress = true }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    -- Bisect delegation
    describe('bisect_start', function()
      it('should delegate to git_bisect.start', function()
        local captured = {}
        git_bisect_stub.start = function(path, opts)
          captured = { path = path, opts = opts }
          return {}, nil
        end

        repo:bisect_start({ term = 'new' })

        assert.are.equal('/repo', captured.path)
        eq({ term = 'new' }, captured.opts)
      end)
    end)

    describe('bisect_bad', function()
      it('should delegate to git_bisect.bad', function()
        local captured = {}
        git_bisect_stub.bad = function(path, commit)
          captured = { path = path, commit = commit }
          return {}, nil
        end

        repo:bisect_bad('abc123')

        assert.are.equal('/repo', captured.path)
        assert.are.equal('abc123', captured.commit)
      end)
    end)

    describe('bisect_good', function()
      it('should delegate to git_bisect.good', function()
        local captured = {}
        git_bisect_stub.good = function(path, commits)
          captured = { path = path, commits = commits }
          return {}, nil
        end

        repo:bisect_good({ 'abc' })

        assert.are.equal('/repo', captured.path)
        eq({ 'abc' }, captured.commits)
      end)
    end)

    describe('bisect_skip', function()
      it('should delegate to git_bisect.skip', function()
        local captured = {}
        git_bisect_stub.skip = function(path, commits)
          captured = { path = path, commits = commits }
          return {}, nil
        end

        repo:bisect_skip({ 'def' })

        assert.are.equal('/repo', captured.path)
        eq({ 'def' }, captured.commits)
      end)
    end)

    describe('bisect_reset', function()
      it('should delegate to git_bisect.reset', function()
        local captured = {}
        git_bisect_stub.reset = function(path, commit)
          captured = { path = path, commit = commit }
          return {}, nil
        end

        repo:bisect_reset('abc123')

        assert.are.equal('/repo', captured.path)
        assert.are.equal('abc123', captured.commit)
      end)
    end)

    describe('bisect_log', function()
      it('should delegate to git_bisect.log', function()
        local captured_path
        git_bisect_stub.log = function(path)
          captured_path = path
          return { 'log line 1', 'log line 2' }, nil
        end

        local result, err = repo:bisect_log()

        assert.is_nil(err)
        eq({ 'log line 1', 'log line 2' }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    describe('bisect_run', function()
      it('should delegate to git_bisect.run', function()
        local captured = {}
        git_bisect_stub.run = function(path, command, args)
          captured = { path = path, command = command, args = args }
          return {}, nil
        end

        repo:bisect_run('make test', { '--verbose' })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('make test', captured.command)
        eq({ '--verbose' }, captured.args)
      end)
    end)

    describe('bisect_status', function()
      it('should delegate to git_bisect.status', function()
        local captured_path
        git_bisect_stub.status = function(path)
          captured_path = path
          return { active = true }, nil
        end

        local result = repo:bisect_status()
        eq({ active = true }, result)
        assert.are.equal('/repo', captured_path)
      end)
    end)

    -- Remote delegation
    describe('add_remote', function()
      it('should delegate to git_remote.add', function()
        local captured = {}
        git_remote_stub.add = function(path, name, url, opts)
          captured = { path = path, name = name, url = url, opts = opts }
          return {}, nil
        end

        repo:add_remote('upstream', 'http://example.com/repo.git', { fetch = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('upstream', captured.name)
        assert.are.equal('http://example.com/repo.git', captured.url)
        eq({ fetch = true }, captured.opts)
      end)
    end)

    describe('remove_remote', function()
      it('should delegate to git_remote.remove', function()
        local captured = {}
        git_remote_stub.remove = function(path, name)
          captured = { path = path, name = name }
          return {}, nil
        end

        repo:remove_remote('upstream')

        assert.are.equal('/repo', captured.path)
        assert.are.equal('upstream', captured.name)
      end)
    end)

    describe('fetch', function()
      it('should delegate to git_remote.fetch', function()
        local captured = {}
        git_remote_stub.fetch = function(path, remote, refspec, opts)
          captured = { path = path, remote = remote, refspec = refspec, opts = opts }
          return {}, nil
        end

        repo:fetch('origin', 'main', { prune = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('origin', captured.remote)
        assert.are.equal('main', captured.refspec)
        eq({ prune = true }, captured.opts)
      end)
    end)

    describe('push', function()
      it('should delegate to git_remote.push', function()
        local captured = {}
        git_remote_stub.push = function(path, remote, refspec, opts)
          captured = { path = path, remote = remote, refspec = refspec, opts = opts }
          return {}, nil
        end

        repo:push('origin', 'main', { force = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('origin', captured.remote)
        assert.are.equal('main', captured.refspec)
        eq({ force = true }, captured.opts)
      end)
    end)

    describe('pull', function()
      it('should delegate to git_remote.pull', function()
        local captured = {}
        git_remote_stub.pull = function(path, remote, refspec, opts)
          captured = { path = path, remote = remote, refspec = refspec, opts = opts }
          return {}, nil
        end

        repo:pull('origin', 'main', { rebase = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('origin', captured.remote)
        assert.are.equal('main', captured.refspec)
        eq({ rebase = true }, captured.opts)
      end)
    end)

    -- Submodule delegation
    describe('add_submodule', function()
      it('should delegate to git_submodule.add', function()
        local captured = {}
        git_submodule_stub.add = function(path, url, subpath, opts)
          captured = { path = path, url = url, subpath = subpath, opts = opts }
          return {}, nil
        end

        repo:add_submodule('http://example.com/sub.git', 'libs/sub', { branch = 'main' })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('http://example.com/sub.git', captured.url)
        assert.are.equal('libs/sub', captured.subpath)
        eq({ branch = 'main' }, captured.opts)
      end)
    end)

    describe('update_submodules', function()
      it('should delegate to git_submodule.update', function()
        local captured = {}
        git_submodule_stub.update = function(path, paths, opts)
          captured = { path = path, paths = paths, opts = opts }
          return {}, nil
        end

        repo:update_submodules({ 'libs/sub' }, { init = true })

        assert.are.equal('/repo', captured.path)
        eq({ 'libs/sub' }, captured.paths)
        eq({ init = true }, captured.opts)
      end)
    end)

    describe('sync_submodules', function()
      it('should delegate to git_submodule.sync', function()
        local captured = {}
        git_submodule_stub.sync = function(path, paths, opts)
          captured = { path = path, paths = paths, opts = opts }
          return {}, nil
        end

        repo:sync_submodules({ 'libs/sub' }, { recursive = true })

        assert.are.equal('/repo', captured.path)
        eq({ 'libs/sub' }, captured.paths)
        eq({ recursive = true }, captured.opts)
      end)
    end)

    describe('submodule_foreach', function()
      it('should delegate to git_submodule.foreach', function()
        local captured = {}
        git_submodule_stub.foreach = function(path, command, opts)
          captured = { path = path, command = command, opts = opts }
          return {}, nil
        end

        repo:submodule_foreach('git pull', { recursive = true })

        assert.are.equal('/repo', captured.path)
        assert.are.equal('git pull', captured.command)
        eq({ recursive = true }, captured.opts)
      end)
    end)

    -- blame_file delegation
    describe('blame_file', function()
      it('should delegate to git_blame.get', function()
        local captured = {}
        package.loaded['vgit.git.git_blame'] = {
          get = function(path, filename, lnum)
            captured = { path = path, filename = filename, lnum = lnum }
            return { author = 'test' }, nil
          end,
        }

        local result, err = repo:blame_file('foo.lua', 42)

        assert.is_nil(err)
        eq({ author = 'test' }, result)
        assert.are.equal('/repo', captured.path)
        assert.are.equal('foo.lua', captured.filename)
        assert.are.equal(42, captured.lnum)

        package.loaded['vgit.git.git_blame'] = nil
      end)
    end)
  end)

  describe('status', function()
    it('should throw when repo is not valid', function()
      local repo = GitRepository()
      repo._state = GitRepository.State.INVALID

      assert.has_error(function()
        repo:status()
      end)
    end)

    it('should delegate to git_status.ls when opts.filename is provided', function()
      local captured = {}
      git_status_stub.ls = function(path, filename)
        captured = { path = path, filename = filename }
        return { status_obj = true }, nil
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:status({ filename = 'test.lua' })

      assert.is_nil(err)
      eq({ status_obj = true }, result)
      assert.are.equal('/repo', captured.path)
      assert.are.equal('test.lua', captured.filename)
    end)

    it('should categorize statuses into staged/changed/unmerged groups', function()
      -- Stub working_tree
      local mock_working_tree = {
        status = function()
          return {
            -- unmerged file
            {
              is_unmerged = function() return true end,
              is_staged = function() return false end,
              is_unstaged = function() return false end,
            },
            -- staged file
            {
              is_unmerged = function() return false end,
              is_staged = function() return true end,
              is_unstaged = function() return false end,
            },
            -- unstaged file
            {
              is_unmerged = function() return false end,
              is_staged = function() return false end,
              is_unstaged = function() return true end,
            },
            -- both staged and unstaged
            {
              is_unmerged = function() return false end,
              is_staged = function() return true end,
              is_unstaged = function() return true end,
            },
          }, nil
        end,
      }

      -- Stub the lazy require of GitWorkingTree
      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:status()

      assert.is_nil(err)
      assert.is_not_nil(result)

      -- Should have 3 sections: Merge Changes, Staged Changes, Changes
      assert.are.equal(3, #result.entries)

      -- Check section titles
      assert.are.equal('Merge Changes', result.entries[1].title)
      assert.are.equal('Staged Changes', result.entries[2].title)
      assert.are.equal('Changes', result.entries[3].title)

      -- Check counts: 1 unmerged, 2 staged (one is both staged+unstaged), 2 changed (one is both)
      assert.are.equal(1, #result.entries[1].entries) -- unmerged
      assert.are.equal(2, #result.entries[2].entries) -- staged
      assert.are.equal(2, #result.entries[3].entries) -- changed/unstaged

      -- Check entry types
      assert.are.equal('unmerged', result.entries[1].entries[1].type)
      assert.are.equal('staged', result.entries[2].entries[1].type)
      assert.are.equal('unstaged', result.entries[3].entries[1].type)

      -- Each entry should have an id field
      assert.is_not_nil(result.entries[1].entries[1].id)
      assert.is_not_nil(result.entries[2].entries[1].id)
      assert.is_not_nil(result.entries[3].entries[1].id)

      -- Each entry should have a status field
      assert.is_not_nil(result.entries[1].entries[1].status)
      assert.is_not_nil(result.entries[2].entries[1].status)
      assert.is_not_nil(result.entries[3].entries[1].status)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should create correct section titles', function()
      -- Only unmerged
      local mock_working_tree = {
        status = function()
          return {
            {
              is_unmerged = function() return true end,
              is_staged = function() return false end,
              is_unstaged = function() return false end,
            },
          }, nil
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')
      local result = repo:status()

      assert.are.equal(1, #result.entries)
      assert.are.equal('Merge Changes', result.entries[1].title)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should omit empty sections', function()
      -- Only staged, no unmerged or unstaged
      local mock_working_tree = {
        status = function()
          return {
            {
              is_unmerged = function() return false end,
              is_staged = function() return true end,
              is_unstaged = function() return false end,
            },
          }, nil
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')
      local result = repo:status()

      assert.are.equal(1, #result.entries)
      assert.are.equal('Staged Changes', result.entries[1].title)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should return layout_type from opts or default unified', function()
      local mock_working_tree = {
        status = function()
          return {}, nil
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')

      -- Default layout_type
      local result = repo:status()
      assert.are.equal('unified', result.layout_type)

      -- Custom layout_type
      result = repo:status({ layout_type = 'split' })
      assert.are.equal('split', result.layout_type)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should return reponame from get_path', function()
      local mock_working_tree = {
        status = function()
          return {}, nil
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/my/project')
      local result = repo:status()

      assert.are.equal('/my/project', result.reponame)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should return error when working_tree status fails', function()
      local mock_working_tree = {
        status = function()
          return nil, { 'status failed' }
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:status()

      assert.is_nil(result)
      eq({ 'status failed' }, err)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)

    it('should return empty entries when no statuses', function()
      local mock_working_tree = {
        status = function()
          return {}, nil
        end,
      }

      package.loaded['vgit.git.GitWorkingTree'] = function()
        return mock_working_tree
      end

      local repo = make_valid_repo('/repo')
      local result = repo:status()

      assert.is_not_nil(result)
      assert.are.equal(0, #result.entries)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)
  end)

  describe('submodules', function()
    it('should return submodule objects from list', function()
      git_submodule_stub.list = function(path)
        return {
          { path = 'libs/sub1' },
          { path = 'libs/sub2' },
        }, nil
      end

      local mock_submodule_constructor_calls = {}
      package.loaded['vgit.git.GitSubmodule'] = function(repo_arg, path)
        local obj = { repo = repo_arg, path = path }
        table.insert(mock_submodule_constructor_calls, obj)
        return obj
      end

      local repo = make_valid_repo('/repo')
      local subs, err = repo:submodules()

      assert.is_nil(err)
      assert.are.equal(2, #subs)
      assert.are.equal('libs/sub1', subs[1].path)
      assert.are.equal('libs/sub2', subs[2].path)

      package.loaded['vgit.git.GitSubmodule'] = nil
    end)

    it('should return error when list fails', function()
      git_submodule_stub.list = function()
        return nil, { 'no submodules support' }
      end

      local repo = make_valid_repo('/repo')
      local subs, err = repo:submodules()

      assert.is_nil(subs)
      eq({ 'no submodules support' }, err)
    end)
  end)

  describe('remotes', function()
    it('should return remote objects from list', function()
      git_remote_stub.list = function(path, opts)
        return {
          { name = 'origin' },
          { name = 'upstream' },
        }, nil
      end

      local mock_remote_calls = {}
      package.loaded['vgit.git.GitRemote'] = function(repo_arg, name)
        local obj = { repo = repo_arg, name = name }
        table.insert(mock_remote_calls, obj)
        return obj
      end

      local repo = make_valid_repo('/repo')
      local remotes, err = repo:remotes()

      assert.is_nil(err)
      assert.are.equal(2, #remotes)
      assert.are.equal('origin', remotes[1].name)
      assert.are.equal('upstream', remotes[2].name)

      package.loaded['vgit.git.GitRemote'] = nil
    end)

    it('should return error when list fails', function()
      git_remote_stub.list = function()
        return nil, { 'list error' }
      end

      local repo = make_valid_repo('/repo')
      local remotes, err = repo:remotes()

      assert.is_nil(remotes)
      eq({ 'list error' }, err)
    end)
  end)

  describe('is_bare', function()
    it('should return the _is_bare field', function()
      local repo = make_valid_repo('/repo')
      repo._is_bare = false
      assert.is_false(repo:is_bare())

      repo._is_bare = true
      assert.is_true(repo:is_bare())
    end)
  end)

  describe('tree', function()
    it('should return a GitTree instance', function()
      local captured = {}
      package.loaded['vgit.git.GitTree'] = function(repo_arg, commit)
        captured = { repo = repo_arg, commit = commit }
        return { type = 'tree' }
      end

      local repo = make_valid_repo('/repo')
      local tree = repo:tree('HEAD')

      eq({ type = 'tree' }, tree)
      assert.are.equal('HEAD', captured.commit)

      package.loaded['vgit.git.GitTree'] = nil
    end)
  end)

  describe('index', function()
    it('should return a GitIndex instance', function()
      package.loaded['vgit.git.GitIndex'] = function(repo_arg)
        return { type = 'index', repo = repo_arg }
      end

      local repo = make_valid_repo('/repo')
      local index, err = repo:index()

      assert.is_nil(err)
      assert.are.equal('index', index.type)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('refs', function()
    it('should return a GitRef instance', function()
      package.loaded['vgit.git.GitRef'] = function(repo_arg)
        return { type = 'ref', repo = repo_arg }
      end

      local repo = make_valid_repo('/repo')
      local refs, err = repo:refs()

      assert.is_nil(err)
      assert.are.equal('ref', refs.type)

      package.loaded['vgit.git.GitRef'] = nil
    end)
  end)

  describe('history', function()
    it('should return a GitHistory instance with opts', function()
      local captured = {}
      package.loaded['vgit.git.GitHistory'] = function(repo_arg, opts)
        captured = { repo = repo_arg, opts = opts }
        return { type = 'history' }
      end

      local repo = make_valid_repo('/repo')
      local history = repo:history({ limit = 10 })

      eq({ type = 'history' }, history)
      eq({ limit = 10 }, captured.opts)

      package.loaded['vgit.git.GitHistory'] = nil
    end)
  end)

  describe('working_tree', function()
    it('should return a GitWorkingTree instance', function()
      package.loaded['vgit.git.GitWorkingTree'] = function(repo_arg)
        return { type = 'working_tree', repo = repo_arg }
      end

      local repo = make_valid_repo('/repo')
      local wt = repo:working_tree()

      assert.are.equal('working_tree', wt.type)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)
  end)

  describe('remote (instance method)', function()
    it('should return a GitRemote instance', function()
      package.loaded['vgit.git.GitRemote'] = function(repo_arg, name)
        return { type = 'remote', name = name }
      end

      local repo = make_valid_repo('/repo')
      local remote, err = repo:remote('origin')

      assert.is_nil(err)
      assert.are.equal('remote', remote.type)
      assert.are.equal('origin', remote.name)

      package.loaded['vgit.git.GitRemote'] = nil
    end)
  end)

  describe('submodule (instance method)', function()
    it('should return a GitSubmodule instance', function()
      package.loaded['vgit.git.GitSubmodule'] = function(repo_arg, path)
        return { type = 'submodule', path = path }
      end

      local repo = make_valid_repo('/repo')
      local sub, err = repo:submodule('libs/sub')

      assert.is_nil(err)
      assert.are.equal('submodule', sub.type)
      assert.are.equal('libs/sub', sub.path)

      package.loaded['vgit.git.GitSubmodule'] = nil
    end)
  end)

  describe('stage_file', function()
    it('should delegate to index:add', function()
      local add_called_with = nil
      package.loaded['vgit.git.GitIndex'] = function()
        return {
          add = function(_, filename)
            add_called_with = filename
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:stage_file('foo.lua')

      assert.is_nil(err)
      assert.are.equal('foo.lua', add_called_with)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('unstage_file', function()
    it('should delegate to index:remove', function()
      local remove_called_with = nil
      package.loaded['vgit.git.GitIndex'] = function()
        return {
          remove = function(_, filename)
            remove_called_with = filename
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:unstage_file('foo.lua')

      assert.is_nil(err)
      assert.are.equal('foo.lua', remove_called_with)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('stage_all', function()
    it('should delegate to index:add with no args', function()
      local add_called = false
      local add_called_with = 'NOT_CALLED'
      package.loaded['vgit.git.GitIndex'] = function()
        return {
          add = function(self, filename)
            add_called = true
            add_called_with = filename
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:stage_all()

      assert.is_nil(err)
      assert.is_true(add_called)
      assert.is_nil(add_called_with)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('unstage_all', function()
    it('should delegate to index:reset', function()
      local reset_called = false
      package.loaded['vgit.git.GitIndex'] = function()
        return {
          reset = function()
            reset_called = true
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:unstage_all()

      assert.is_nil(err)
      assert.is_true(reset_called)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('file_content', function()
    it('should create GitBlob and call content', function()
      local captured = {}
      package.loaded['vgit.git.GitBlob'] = function(repo_arg, filename, commit)
        captured = { repo = repo_arg, filename = filename, commit = commit }
        return {
          content = function()
            return 'file content here', nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:file_content('foo.lua', 'HEAD')

      assert.is_nil(err)
      assert.are.equal('file content here', result)
      assert.are.equal('foo.lua', captured.filename)
      assert.are.equal('HEAD', captured.commit)

      package.loaded['vgit.git.GitBlob'] = nil
    end)
  end)

  describe('file_lines', function()
    it('should create GitBlob and call lines', function()
      local captured = {}
      package.loaded['vgit.git.GitBlob'] = function(repo_arg, filename, commit)
        captured = { repo = repo_arg, filename = filename, commit = commit }
        return {
          lines = function()
            return { 'line1', 'line2' }, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local result, err = repo:file_lines('bar.lua', 'abc123')

      assert.is_nil(err)
      eq({ 'line1', 'line2' }, result)
      assert.are.equal('bar.lua', captured.filename)
      assert.are.equal('abc123', captured.commit)

      package.loaded['vgit.git.GitBlob'] = nil
    end)
  end)

  describe('commit', function()
    it('should delegate to index:commit', function()
      local commit_message = nil
      package.loaded['vgit.git.GitIndex'] = function()
        return {
          commit = function(_, message)
            commit_message = message
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:commit('Initial commit')

      assert.is_nil(err)
      assert.are.equal('Initial commit', commit_message)

      package.loaded['vgit.git.GitIndex'] = nil
    end)
  end)

  describe('reset', function()
    it('should delegate to working_tree:reset', function()
      local reset_filename = nil
      package.loaded['vgit.git.GitWorkingTree'] = function()
        return {
          reset = function(_, filename)
            reset_filename = filename
            return {}, nil
          end,
        }
      end

      local repo = make_valid_repo('/repo')
      local _, err = repo:reset('foo.lua')

      assert.is_nil(err)
      assert.are.equal('foo.lua', reset_filename)

      package.loaded['vgit.git.GitWorkingTree'] = nil
    end)
  end)
end)
