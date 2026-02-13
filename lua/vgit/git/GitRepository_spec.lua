local GitRepository = require('vgit.git.GitRepository')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

describe('GitRepository:', function()
  -- ================================================================
  -- Unit tests (no repo needed)
  -- ================================================================
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

  describe('get_path', function()
    it('should return stored path', function()
      local repo = GitRepository('/my/repo')
      repo._state = GitRepository.State.VALID
      assert.are.equal('/my/repo', repo:get_path())
    end)

    it('should return nil when no path set', function()
      local repo = GitRepository()
      repo._state = GitRepository.State.INVALID
      assert.is_nil(repo:get_path())
    end)
  end)

  describe('is_bare', function()
    it('should return the _is_bare field', function()
      local repo = GitRepository('/repo')
      repo._state = GitRepository.State.VALID
      repo._is_bare = false
      assert.is_false(repo:is_bare())
    end)
  end)

  describe('assertion validation', function()
    local repo

    before_each(function()
      repo = GitRepository('/repo')
      repo._state = GitRepository.State.VALID
    end)

    it('is_ignored requires filename', function()
      assert.has_error(function() repo:is_ignored(nil) end)
    end)

    it('has_file requires filename', function()
      assert.has_error(function() repo:has_file(nil) end)
    end)

    it('merge requires commit', function()
      assert.has_error(function() repo:merge(nil) end)
    end)

    it('merge_base requires first commit', function()
      assert.has_error(function() repo:merge_base(nil, 'abc') end)
    end)

    it('merge_base requires second commit', function()
      assert.has_error(function() repo:merge_base('abc', nil) end)
    end)

    it('is_ancestor requires ancestor', function()
      assert.has_error(function() repo:is_ancestor(nil, 'desc') end)
    end)

    it('is_ancestor requires descendant', function()
      assert.has_error(function() repo:is_ancestor('anc', nil) end)
    end)

    it('rebase requires upstream', function()
      assert.has_error(function() repo:rebase(nil) end)
    end)

    it('cherry_pick requires commits', function()
      assert.has_error(function() repo:cherry_pick(nil) end)
    end)

    it('revert requires commits', function()
      assert.has_error(function() repo:revert(nil) end)
    end)

    it('bisect_run requires command', function()
      assert.has_error(function() repo:bisect_run(nil) end)
    end)

    it('remote requires name', function()
      assert.has_error(function() repo:remote(nil) end)
    end)

    it('add_remote requires name', function()
      assert.has_error(function() repo:add_remote(nil, 'http://url') end)
    end)

    it('add_remote requires url', function()
      assert.has_error(function() repo:add_remote('origin', nil) end)
    end)

    it('remove_remote requires name', function()
      assert.has_error(function() repo:remove_remote(nil) end)
    end)

    it('file_content requires filename', function()
      assert.has_error(function() repo:file_content(nil) end)
    end)

    it('file_lines requires filename', function()
      assert.has_error(function() repo:file_lines(nil) end)
    end)

    it('stage_file requires filename', function()
      assert.has_error(function() repo:stage_file(nil) end)
    end)

    it('unstage_file requires filename', function()
      assert.has_error(function() repo:unstage_file(nil) end)
    end)

    it('stage_hunk requires filename', function()
      assert.has_error(function() repo:stage_hunk(nil, { start = 1 }) end)
    end)

    it('stage_hunk requires hunk', function()
      assert.has_error(function() repo:stage_hunk('file.txt', nil) end)
    end)

    it('unstage_hunk requires filename', function()
      assert.has_error(function() repo:unstage_hunk(nil, { start = 1 }) end)
    end)

    it('unstage_hunk requires hunk', function()
      assert.has_error(function() repo:unstage_hunk('file.txt', nil) end)
    end)

    it('reset_hunk requires filename', function()
      assert.has_error(function() repo:reset_hunk(nil, { start = 1 }) end)
    end)

    it('reset_hunk requires hunk', function()
      assert.has_error(function() repo:reset_hunk('file.txt', nil) end)
    end)

    it('commit requires non-empty message', function()
      assert.has_error(function() repo:commit(nil) end)
      assert.has_error(function() repo:commit('') end)
    end)

    it('reset requires filename', function()
      assert.has_error(function() repo:reset(nil) end)
    end)

    it('submodule requires path', function()
      assert.has_error(function() repo:submodule(nil) end)
    end)

    it('add_submodule requires url', function()
      assert.has_error(function() repo:add_submodule(nil, '/path') end)
    end)

    it('add_submodule requires path', function()
      assert.has_error(function() repo:add_submodule('http://url', nil) end)
    end)

    it('submodule_foreach requires command', function()
      assert.has_error(function() repo:submodule_foreach(nil) end)
    end)

    it('blame_file requires filename', function()
      assert.has_error(function() repo:blame_file(nil) end)
    end)
  end)

  describe('open (static)', function()
    it('should return nil and error when path is nil', function()
      local repo, err = GitRepository.open(nil)
      assert.is_nil(repo)
      eq({ 'path is required' }, err)
    end)
  end)

  -- ================================================================
  -- Integration tests (real repo)
  -- ================================================================
  describe('integration', function()
    local repo_path
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err
      repo_path, err = test_repo.create_repo({
        initial_commit = true,
        files = {
          ['file.txt'] = { 'line one', 'line two', 'line three' },
          ['src/main.lua'] = { 'print("hello")' },
        },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo_path then test_repo.cleanup(repo_path) end
    end)

    describe('open', function()
      it('should return a VALID repo for a real git directory', function()
        local repo, err = GitRepository.open(repo_path)
        assert.is_nil(err)
        assert.is_not_nil(repo)
        assert.are.equal(GitRepository.State.VALID, repo._state)
        assert.are.equal(repo_path, repo._path)
      end)

      it('should return error for non-existent path', function()
        local repo, err = GitRepository.open('/nonexistent/path/that/does/not/exist')
        assert.is_nil(repo)
        assert.is_not_nil(err)
      end)
    end)

    describe('is_valid', function()
      it('should return true for a real git repository', function()
        local repo, err = GitRepository.open(repo_path)
        assert.is_nil(err)
        assert.is_true(repo:is_valid())
      end)

      it('should return false for a non-git directory', function()
        local temp = vim.fn.tempname()
        vim.fn.mkdir(temp, 'p')
        local repo = GitRepository(temp)
        assert.is_false(repo:is_valid())
        vim.fn.delete(temp, 'rf')
      end)
    end)

    describe('get_path', function()
      it('should return the repo path after open', function()
        local repo = GitRepository.open(repo_path)
        assert.are.equal(repo_path, repo:get_path())
      end)
    end)

    describe('has_file', function()
      it('should return true for a committed file', function()
        local repo = GitRepository.open(repo_path)
        local result, err = repo:has_file('file.txt')
        assert.is_nil(err)
        assert.is_true(result)
      end)

      it('should return false for a non-existent file', function()
        local repo = GitRepository.open(repo_path)
        local result, err = repo:has_file('nonexistent.txt')
        assert.is_nil(err)
        assert.is_false(result)
      end)
    end)

    describe('tree', function()
      it('should return a GitTree for HEAD', function()
        local repo = GitRepository.open(repo_path)
        local tree = repo:tree('HEAD')
        assert.is_not_nil(tree)
        assert.are.equal('HEAD', tree:ref())
      end)

      it('should return a GitTree for a specific commit', function()
        local repo = GitRepository.open(repo_path)
        local commit_hash = test_repo.get_head_commit(repo_path)
        local tree = repo:tree(commit_hash)
        assert.is_not_nil(tree)
        assert.are.equal(commit_hash, tree:ref())
      end)
    end)

    describe('index', function()
      it('should return a GitIndex object', function()
        local repo = GitRepository.open(repo_path)
        local index, err = repo:index()
        assert.is_nil(err)
        assert.is_not_nil(index)
      end)

      it('should return a GitIndex that reports clean repo', function()
        local repo = GitRepository.open(repo_path)
        local index = repo:index()
        local is_clean, err = index:is_clean()
        assert.is_nil(err)
        assert.is_true(is_clean)
      end)
    end)

    describe('refs', function()
      it('should return a GitRef object', function()
        local repo = GitRepository.open(repo_path)
        local refs, err = repo:refs()
        assert.is_nil(err)
        assert.is_not_nil(refs)
      end)

      it('should return refs that can list branches', function()
        local repo = GitRepository.open(repo_path)
        local refs = repo:refs()
        local branches, err = refs:branches()
        assert.is_nil(err)
        assert.is_true(#branches >= 1)
      end)
    end)

    describe('history', function()
      it('should return a GitHistory object', function()
        local repo = GitRepository.open(repo_path)
        local history = repo:history()
        assert.is_not_nil(history)
      end)

      it('should return history with commits', function()
        local repo = GitRepository.open(repo_path)
        local history = repo:history()
        local count, err = history:count()
        assert.is_nil(err)
        assert.is_true(count >= 1)
      end)
    end)

    describe('file_lines', function()
      it('should return lines of a committed file', function()
        local repo = GitRepository.open(repo_path)
        local lines, err = repo:file_lines('file.txt')
        assert.is_nil(err)
        assert.is_not_nil(lines)
        eq('line one', lines[1])
        eq('line two', lines[2])
        eq('line three', lines[3])
      end)
    end)

    describe('stage_file', function()
      it('should stage a modified file', function()
        test_repo.write_file(repo_path, 'file.txt', { 'modified line' })

        local repo = GitRepository.open(repo_path)
        local result, err = repo:stage_file('file.txt')
        assert.is_nil(err)
        assert.is_not_nil(result)

        -- Verify file is staged
        local index = repo:index()
        local has_staged, staged_err = index:has_staged_changes()
        assert.is_nil(staged_err)
        assert.is_true(has_staged)
      end)
    end)

    describe('unstage_file', function()
      it('should unstage a staged file', function()
        test_repo.write_file(repo_path, 'file.txt', { 'modified line' })
        test_repo.stage(repo_path, { 'file.txt' })

        local repo = GitRepository.open(repo_path)

        -- Verify it's staged first
        local index = repo:index()
        local has_staged, _ = index:has_staged_changes()
        assert.is_true(has_staged)

        -- Unstage
        local result, err = repo:unstage_file('file.txt')
        assert.is_nil(err)
        assert.is_not_nil(result)

        -- Verify it's no longer staged
        index:reset_cache()
        has_staged, _ = index:has_staged_changes()
        assert.is_false(has_staged)
      end)
    end)

    describe('commit', function()
      it('should commit staged changes', function()
        test_repo.write_file(repo_path, 'file.txt', { 'modified content' })
        test_repo.stage(repo_path, { 'file.txt' })

        local repo = GitRepository.open(repo_path)
        local result, err = repo:commit('Test commit message')
        assert.is_nil(err)
        assert.is_not_nil(result)

        -- Verify repo is clean after commit
        local index = repo:index()
        local is_clean, clean_err = index:is_clean()
        assert.is_nil(clean_err)
        assert.is_true(is_clean)
      end)

      it('should fail when no staged changes', function()
        local repo = GitRepository.open(repo_path)
        local result, err = repo:commit('No changes')
        assert.is_nil(result)
        assert.is_not_nil(err)
      end)
    end)

    describe('working_tree', function()
      it('should return a GitWorkingTree object', function()
        local repo = GitRepository.open(repo_path)
        local wt = repo:working_tree()
        assert.is_not_nil(wt)
      end)
    end)

    describe('_ensure_initialized', function()
      it('should set VALID when path is a real repo', function()
        local repo = GitRepository(repo_path)
        assert.are.equal(GitRepository.State.UNINITIALIZED, repo._state)
        repo:_ensure_initialized()
        assert.are.equal(GitRepository.State.VALID, repo._state)
      end)

      it('should set INVALID when path is not a repo', function()
        local temp = vim.fn.tempname()
        vim.fn.mkdir(temp, 'p')
        local repo = GitRepository(temp)
        repo:_ensure_initialized()
        assert.are.equal(GitRepository.State.INVALID, repo._state)
        vim.fn.delete(temp, 'rf')
      end)

      it('should be idempotent - not re-initialize when already VALID', function()
        local repo = GitRepository(repo_path)
        repo:_ensure_initialized()
        assert.are.equal(GitRepository.State.VALID, repo._state)

        -- Change path to something invalid (should not re-check)
        repo._path = '/nonexistent'
        repo:_ensure_initialized()
        -- Still VALID because it doesn't re-check
        assert.are.equal(GitRepository.State.VALID, repo._state)
      end)
    end)

    describe('is_ignored', function()
      it('should return false for a committed file', function()
        local repo = GitRepository.open(repo_path)
        local result, err = repo:is_ignored('file.txt')
        assert.is_nil(err)
        assert.is_false(result)
      end)
    end)

    describe('status with filename', function()
      it('should return status for a specific file when modified', function()
        test_repo.write_file(repo_path, 'file.txt', { 'changed content' })

        local repo = GitRepository.open(repo_path)
        local result, err = repo:status({ filename = 'file.txt' })
        assert.is_nil(err)
        assert.is_not_nil(result)
      end)
    end)

    describe('stage_all', function()
      it('should stage all modified files', function()
        test_repo.write_file(repo_path, 'file.txt', { 'modified' })
        test_repo.write_file(repo_path, 'src/main.lua', { 'modified lua' })

        local repo = GitRepository.open(repo_path)
        local _, err = repo:stage_all()
        assert.is_nil(err)

        local index = repo:index()
        local has_staged, staged_err = index:has_staged_changes()
        assert.is_nil(staged_err)
        assert.is_true(has_staged)
      end)
    end)

    describe('discover', function()
      it('should find repo from nested subdirectory', function()
        -- Create a subdirectory
        vim.fn.mkdir(repo_path .. '/subdir/nested', 'p')

        local repo, err = GitRepository.discover(repo_path .. '/subdir/nested')
        assert.is_nil(err)
        assert.is_not_nil(repo)
        assert.are.equal(GitRepository.State.VALID, repo._state)
        eq(repo_path, repo:get_path())
      end)
    end)

    describe('blame_file', function()
      it('should return blame for committed file', function()
        local repo = GitRepository.open(repo_path)
        local result, err = repo:blame_file('file.txt', 1)

        assert.is_nil(err)
        assert.is_not_nil(result)
      end)
    end)

    describe('remotes', function()
      it('should return empty list for local-only repo', function()
        local repo = GitRepository.open(repo_path)
        local remotes, err = repo:remotes()

        assert.is_nil(err)
        assert.is_not_nil(remotes)
        eq(0, #remotes)
      end)
    end)

    describe('submodules', function()
      it('should return empty list when none exist', function()
        local repo = GitRepository.open(repo_path)
        local subs, err = repo:submodules()

        assert.is_nil(err)
        assert.is_not_nil(subs)
        eq(0, #subs)
      end)
    end)

    describe('unstage_all', function()
      it('should unstage all staged files', function()
        test_repo.write_file(repo_path, 'file.txt', { 'modified' })
        test_repo.stage(repo_path, { 'file.txt' })

        local repo = GitRepository.open(repo_path)

        local _, err = repo:unstage_all()
        assert.is_nil(err)

        local index = repo:index()
        local has_staged, staged_err = index:has_staged_changes()
        assert.is_nil(staged_err)
        assert.is_false(has_staged)
      end)
    end)
  end)
end)
