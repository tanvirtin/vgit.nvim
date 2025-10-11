local test_harness = require('ops.lib.test_harness')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitRepository', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({ initial_commit = false })
    assert(not err, 'Failed to create test repo')
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('constructor and creation', function()
    it('creates a repository instance', function()
      local new_repo = GitRepository()
      assert(new_repo ~= nil, 'repository should be created')
      assert(new_repo._state == GitRepository.State.UNINITIALIZED, 'should be uninitialized')
    end)

    it('creates a repository with path', function()
      local git_repo = GitRepository(repo)
      assert(git_repo ~= nil, 'repository should be created')
      assert(git_repo._path == test_repo.dir, 'path should be set')
    end)
  end)

  describe('discover', function()
    it('discovers repository from current directory', function()
      local git_repo, err = GitRepository.discover(repo)
      assert(err == nil, 'should not return error')
      assert(git_repo ~= nil, 'repository should be discovered')
      assert(git_repo:is_valid(), 'repository should be valid')
    end)

    it('returns error for non-repository path', function()
      local temp_dir = '/tmp/not-a-repo-' .. os.time()
      vim.fn.mkdir(temp_dir, 'p')

      local _, err = GitRepository.discover(temp_dir)
      assert(err ~= nil, 'should return error')

      vim.fn.delete(temp_dir, 'rf')
    end)
  end)

  describe('open', function()
    it('opens a repository at a specific path', function()
      local git_repo, err = GitRepository.open(repo)
      assert(err == nil, 'should not return error')
      assert(git_repo ~= nil, 'repository should be opened')
      assert(git_repo:is_valid(), 'repository should be valid')
    end)

    it('returns error when path is not provided', function()
      local opened_repo, err = GitRepository.open(nil)
      assert(err ~= nil, 'should return error')
      assert(opened_repo == nil, 'repository should be nil')
    end)

    it('returns error for invalid path', function()
      local opened_repo, err = GitRepository.open('/tmp/invalid-repo-path')
      assert(err ~= nil, 'should return error')
      assert(opened_repo == nil, 'repository should be nil')
    end)
  end)

  describe('is_valid', function()
    it('returns true for valid repository', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      assert(opened_repo:is_valid(), 'should be valid')
    end)

    it('returns false for invalid repository', function()
      local invalid_repo = GitRepository()
      invalid_repo._state = GitRepository.State.INVALID
      assert(not invalid_repo:is_valid(), 'should be invalid')
    end)
  end)

  describe('get_path', function()
    it('returns repository path', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      assert(opened_repo:get_path() == test_repo.dir, 'should return correct path')
    end)
  end)

  describe('get_git_dir', function()
    it('returns .git directory path', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local git_dir, err = opened_repo:get_git_dir()
      assert(err == nil, 'should not return error')
      assert(git_dir ~= nil, 'should return git dir')
      assert(git_dir:match('%.git'), 'should contain .git')
    end)
  end)

  describe('status', function()
    it('returns empty status for clean repository', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local status, err = opened_repo:status()
      assert(err == nil, 'should not return error')
      assert(type(status) == 'table', 'should return table')
      assert(#status == 0, 'should be empty for clean repo')
    end)

    it('returns status for modified files', function()
      -- Create and commit a file
      test_repo:create_file('test.txt', { 'original content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')

      -- Modify the file
      test_repo:create_file('test.txt', { 'modified content' })

      local opened_repo = GitRepository.open(test_repo.dir)
      local status, err = opened_repo:status()
      assert(err == nil, 'should not return error')
      assert(#status > 0, 'should have changes')
    end)

    it('returns status for specific file', function()
      test_repo:create_file('test.txt', { 'content' })

      local opened_repo = GitRepository.open(test_repo.dir)
      local status, err = opened_repo:file_status('test.txt')
      assert(err == nil, 'should not return error')
      assert(status ~= nil, 'should return status')
    end)
  end)

  describe('has_file', function()
    it('returns true for existing file', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Add test.txt')

      local opened_repo = GitRepository.open(test_repo.dir)
      local has_file, err = opened_repo:has_file('test.txt')
      assert(err == nil, 'should not return error')
      assert(has_file == true, 'file should exist')
    end)

    it('returns false for non-existing file', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local has_file, err = opened_repo:has_file('nonexistent.txt')
      assert(err == nil, 'should not return error')
      assert(has_file == false, 'file should not exist')
    end)

    it('requires filename', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local _, err = opened_repo:has_file(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('tree', function()
    it('creates a GitTree for HEAD', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')

      local opened_repo = GitRepository.open(test_repo.dir)
      local tree = opened_repo:tree('HEAD')
      assert(tree ~= nil, 'tree should be created')
      assert(tree._commit_ref == 'HEAD', 'should reference HEAD')
    end)
  end)

  describe('index', function()
    it('creates a GitIndex', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local index, err = opened_repo:index()
      assert(err == nil, 'should not return error')
      assert(index ~= nil, 'index should be created')
    end)

    it('returns cached index on subsequent calls', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local index1, _ = opened_repo:index()
      local index2, _ = opened_repo:index()
      assert(index1 == index2, 'should return same instance')
    end)
  end)

  describe('refs', function()
    it('creates a GitRef', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local refs, err = opened_repo:refs()
      assert(err == nil, 'should not return error')
      assert(refs ~= nil, 'refs should be created')
    end)

    it('returns cached refs on subsequent calls', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local refs1, _ = opened_repo:refs()
      local refs2, _ = opened_repo:refs()
      assert(refs1 == refs2, 'should return same instance')
    end)
  end)

  -- Removed: blame() tests
  -- Use git_blame.get() or git_blame.list() directly

  describe('history', function()
    it('creates GitHistory', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')

      local opened_repo = GitRepository.open(test_repo.dir)
      local history = opened_repo:history()
      assert(history ~= nil, 'history should be created')
    end)

    it('accepts options', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')

      local opened_repo = GitRepository.open(test_repo.dir)
      local history = opened_repo:history({ count = 10 })
      assert(history ~= nil, 'history should be created')
      assert(history._count == 10, 'should have correct count')
    end)
  end)

  describe('working_tree', function()
    it('creates GitWorkingTree', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local wt = opened_repo:working_tree()
      assert(wt ~= nil, 'working tree should be created')
    end)
  end)

  describe('reset', function()
    it('clears cached data', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      opened_repo:index() -- Create cache
      opened_repo:refs() -- Create cache

      opened_repo:reset()

      assert(opened_repo._index == nil, 'index cache should be cleared')
      assert(opened_repo._refs == nil, 'refs cache should be cleared')
    end)
  end)

  describe('__tostring', function()
    it('returns string representation', function()
      local opened_repo = GitRepository.open(test_repo.dir)
      local str = tostring(opened_repo)
      assert(type(str) == 'string', 'should return string')
      assert(str:match('GitRepository'), 'should contain class name')
    end)
  end)

  describe('file-level operations', function()
    describe('blame_file', function()
      it('returns blame for a file line', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2', 'line 3' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Initial commit')

        local opened_repo = GitRepository.open(test_repo.dir)
        local blame, err = opened_repo:blame_file('test.txt', 1)

        assert(err == nil, 'should not return error')
        assert(blame ~= nil, 'should return blame')
        assert(blame.commit_hash ~= nil, 'should have commit hash')
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:blame_file(nil, 1)

        assert(err ~= nil, 'should return error')
      end)

      it('returns error for non-existent file', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:blame_file('nonexistent.txt', 1)

        assert(err ~= nil, 'should return error')
      end)
    end)

    describe('file_content', function()
      it('returns file content from HEAD', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        local opened_repo = GitRepository.open(test_repo.dir)
        local content, err = opened_repo:file_content('test.txt')

        assert(err == nil, 'should not return error')
        assert(content ~= nil, 'should return content')
        assert(content:match('line 1'), 'should contain file content')
      end)

      it('returns file content from specific commit', function()
        test_repo.write_file(repo, 'test.txt', { 'version 1' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'First version')
        local first_commit = test_repo.get_last_commit_hash(repo)

        test_repo.write_file(repo, 'test.txt', { 'version 2' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Second version')

        local opened_repo = GitRepository.open(test_repo.dir)
        local content, err = opened_repo:file_content('test.txt', first_commit)

        assert(err == nil, 'should not return error')
        assert(content:match('version 1'), 'should return first version')
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:file_content(nil)

        assert(err ~= nil, 'should return error')
      end)
    end)

    describe('file_lines', function()
      it('returns file lines from HEAD', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2', 'line 3' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        local opened_repo = GitRepository.open(test_repo.dir)
        local lines, err = opened_repo:file_lines('test.txt')

        assert(err == nil, 'should not return error')
        assert(type(lines) == 'table', 'should return table')
        assert(#lines == 3, 'should have 3 lines')
        assert(lines[1] == 'line 1', 'first line should match')
      end)

      it('returns file lines from specific commit', function()
        test_repo.write_file(repo, 'test.txt', { 'old content' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'First version')
        local first_commit = test_repo.get_last_commit_hash(repo)

        test_repo.write_file(repo, 'test.txt', { 'new content' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Second version')

        local opened_repo = GitRepository.open(test_repo.dir)
        local lines, err = opened_repo:file_lines('test.txt', first_commit)

        assert(err == nil, 'should not return error')
        assert(lines[1] == 'old content', 'should return old content')
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:file_lines(nil)

        assert(err ~= nil, 'should return error')
      end)
    end)

    describe('has_file', function()
      it('returns true for tracked file', function()
        test_repo.write_file(repo, 'test.txt', { 'content' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        local opened_repo = GitRepository.open(test_repo.dir)
        local has_file, err = opened_repo:has_file('test.txt')

        assert(err == nil, 'should not return error')
        assert(has_file == true, 'should return true for tracked file')
      end)

      it('returns false for untracked file', function()
        test_repo.write_file(repo, 'untracked.txt', { 'content' })

        local opened_repo = GitRepository.open(test_repo.dir)
        local has_file, err = opened_repo:has_file('untracked.txt')

        assert(err == nil, 'should not return error')
        assert(has_file == false, 'should return false for untracked file')
      end)

      it('checks file existence at specific commit', function()
        test_repo.write_file(repo, 'test.txt', { 'content' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')
        local first_commit = test_repo.get_last_commit_hash(repo)

        test_repo.delete_file(repo, 'test.txt')
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Delete test file')

        local opened_repo = GitRepository.open(test_repo.dir)
        local has_in_first, err1 = opened_repo:has_file('test.txt', first_commit)
        local has_in_head, err2 = opened_repo:has_file('test.txt', 'HEAD')

        assert(err1 == nil and err2 == nil, 'should not return errors')
        assert(has_in_first == true, 'should exist in first commit')
        assert(has_in_head == false, 'should not exist in HEAD')
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:has_file(nil)

        assert(err ~= nil, 'should return error')
      end)
    end)

    describe('file_status', function()
      it('returns status for modified file', function()
        test_repo.write_file(repo, 'test.txt', { 'original' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        test_repo.write_file(repo, 'test.txt', { 'modified' })

        local opened_repo = GitRepository.open(test_repo.dir)
        local status, err = opened_repo:file_status('test.txt')

        assert(err == nil, 'should not return error')
        assert(status ~= nil, 'should return status')
      end)

      it('returns nil for non-existent file', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local status, err = opened_repo:file_status('nonexistent.txt')

        assert(err == nil, 'should not return error')
        assert(status == nil, 'should return nil for non-existent file')
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:file_status(nil)

        assert(err ~= nil, 'should return error')
      end)
    end)
  end)

  describe('staging operations', function()
    describe('stage_file', function()
      it('stages a modified file', function()
        test_repo.write_file(repo, 'test.txt', { 'original' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        test_repo.write_file(repo, 'test.txt', { 'modified' })

        local opened_repo = GitRepository.open(test_repo.dir)
        local result, err = opened_repo:stage_file('test.txt')

        assert(err == nil, 'should not return error')
        assert(result ~= nil, 'should return result')

        -- Verify file is staged
        local index = opened_repo:index()
        local staged, _ = index:has_staged_changes()
        assert(staged == true, 'file should be staged')
      end)

      it('stages a new file', function()
        test_repo.write_file(repo, 'new.txt', { 'content' })

        local opened_repo = GitRepository.open(test_repo.dir)
        local result, err = opened_repo:stage_file('new.txt')

        assert(err == nil, 'should not return error')
        assert(result ~= nil, 'should return result')
      end)
    end)

    describe('unstage_file', function()
      it('unstages a staged file', function()
        test_repo.write_file(repo, 'test.txt', { 'original' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        test_repo.write_file(repo, 'test.txt', { 'modified' })
        test_repo.stage(repo, 'test.txt')

        local opened_repo = GitRepository.open(test_repo.dir)
        local result, err = opened_repo:unstage_file('test.txt')

        assert(err == nil, 'should not return error')
        assert(result ~= nil, 'should return result')

        -- Verify file is unstaged
        local index = opened_repo:index()
        local staged, _ = index:has_staged_changes()
        assert(staged == false, 'file should be unstaged')
      end)
    end)

    describe('stage_hunk', function()
      it('stages a specific hunk', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2', 'line 3' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        test_repo.write_file(repo, 'test.txt', { 'modified 1', 'line 2', 'modified 3' })

        local opened_repo = GitRepository.open(test_repo.dir)
        local wt = opened_repo:working_tree()
        local hunks, _ = wt:live_hunks('test.txt', { 'modified 1', 'line 2', 'modified 3' })

        if hunks and #hunks > 0 then
          local result, err = opened_repo:stage_hunk('test.txt', hunks[1])
          assert(err == nil, 'should not return error')
          assert(result ~= nil, 'should return result')
        end
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:stage_hunk(nil, {})

        assert(err ~= nil, 'should return error')
      end)

      it('returns error when hunk is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:stage_hunk('test.txt', nil)

        assert(err ~= nil, 'should return error')
      end)
    end)

    describe('unstage_hunk', function()
      it('unstages a specific hunk', function()
        test_repo.write_file(repo, 'test.txt', { 'line 1', 'line 2' })
        test_repo.stage(repo, 'test.txt')
        test_repo.commit(repo, 'Add test file')

        test_repo.write_file(repo, 'test.txt', { 'modified 1', 'modified 2' })
        test_repo.stage(repo, 'test.txt')

        local opened_repo = GitRepository.open(test_repo.dir)
        local index = opened_repo:index()
        local hunks, _ = index:staged_hunks('test.txt')

        if hunks and #hunks > 0 then
          local result, err = opened_repo:unstage_hunk('test.txt', hunks[1])
          assert(err == nil, 'should not return error')
          assert(result ~= nil, 'should return result')
        end
      end)

      it('returns error when filename is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:unstage_hunk(nil, {})

        assert(err ~= nil, 'should return error')
      end)

      it('returns error when hunk is missing', function()
        local opened_repo = GitRepository.open(test_repo.dir)
        local _, err = opened_repo:unstage_hunk('test.txt', nil)

        assert(err ~= nil, 'should return error')
      end)
    end)
  end)
end)
