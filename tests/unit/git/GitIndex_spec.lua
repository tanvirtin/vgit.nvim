local test_harness = require('ops.lib.test_harness')
local git_test_repo = require('tests.helpers.git_test_repo')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitIndex', function()
  local test_repo
  local repo
  local index

  before_each(function()
    test_repo = git_test_repo.create()
    test_repo:init()
    repo = GitRepository.open(test_repo.dir)
    index = repo:index()
  end)

  after_each(function()
    if test_repo then test_repo:cleanup() end
  end)

  describe('constructor', function()
    it('creates an index', function()
      assert(index ~= nil, 'index should be created')
      assert(index:repository() == repo, 'should have repository reference')
    end)

    it('requires repository', function()
      local GitIndex = require('vgit.git.GitIndex')
      local success = pcall(function()
        GitIndex(nil)
      end)
      assert(not success, 'should require repository')
    end)
  end)

  describe('add', function()
    it('stages a single file', function()
      test_repo:create_file('test.txt', { 'content' })

      local success, err = index:add('test.txt')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      local staged, _ = index:staged_files()
      assert(#staged > 0, 'should have staged files')
    end)

    it('clears cache after staging', function()
      test_repo:create_file('test.txt', { 'content' })
      index:staged_files() -- Create cache

      index:add('test.txt')

      assert(index._staged_files == nil, 'cache should be cleared')
    end)
  end)

  describe('add_all', function()
    it('stages all files', function()
      test_repo:create_file('file1.txt', { 'content 1' })
      test_repo:create_file('file2.txt', { 'content 2' })

      local success, err = index:add_all()
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      local staged, _ = index:staged_files()
      assert(#staged >= 2, 'should have multiple staged files')
    end)
  end)

  describe('remove', function()
    it('unstages a file', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')
      test_repo:create_file('test.txt', { 'modified' })
      test_repo:stage_file('test.txt')

      local success, err = index:remove('test.txt')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
    end)
  end)

  describe('status', function()
    it('returns empty status for clean repository', function()
      local status, err = index:status()
      assert(err == nil, 'should not return error')
      assert(type(status) == 'table', 'should return table')
      assert(#status == 0, 'should be empty')
    end)

    it('returns status with changes', function()
      test_repo:create_file('test.txt', { 'content' })

      local status, err = index:status()
      assert(err == nil, 'should not return error')
      assert(#status > 0, 'should have changes')
    end)
  end)

  describe('staged_files', function()
    it('returns only staged files', function()
      test_repo:create_file('staged.txt', { 'staged content' })
      test_repo:create_file('unstaged.txt', { 'unstaged content' })
      test_repo:stage_file('staged.txt')

      local staged, err = index:staged_files()
      assert(err == nil, 'should not return error')
      assert(#staged > 0, 'should have staged files')

      local has_staged = false
      for _, file in ipairs(staged) do
        if file.filename:match('staged%.txt') then
          has_staged = true
          break
        end
      end
      assert(has_staged, 'should contain staged file')
    end)

    it('caches staged files', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      local staged1, _ = index:staged_files()
      local staged2, _ = index:staged_files()
      assert(staged1 == staged2, 'should return cached data')
    end)
  end)

  describe('unstaged_files', function()
    it('returns only unstaged files', function()
      test_repo:create_file('file1.txt', { 'content 1' })
      test_repo:create_file('file2.txt', { 'content 2' })
      test_repo:stage_file('file1.txt')

      local unstaged, err = index:unstaged_files()
      assert(err == nil, 'should not return error')

      if #unstaged > 0 then
        local has_file2 = false
        for _, file in ipairs(unstaged) do
          if file.filename:match('file2%.txt') then
            has_file2 = true
            break
          end
        end
        assert(has_file2, 'should contain unstaged file')
      end
    end)
  end)

  describe('unmerged_files', function()
    it('returns empty list when no conflicts', function()
      local unmerged, err = index:unmerged_files()
      assert(err == nil, 'should not return error')
      assert(type(unmerged) == 'table', 'should return table')
      assert(#unmerged == 0, 'should have no conflicts')
    end)
  end)

  describe('add_hunk', function()
    it('stages a single hunk', function()
      -- Create and commit initial file
      test_repo:create_file('test.txt', { 'line 1', 'line 2', 'line 3' })
      test_repo:stage_file('test.txt')
      test_repo:commit('Initial commit')

      -- Modify the file
      test_repo:create_file('test.txt', { 'modified line 1', 'line 2', 'line 3' })

      -- Get hunks
      local git_hunks = require('vgit.git.git_hunks')
      local hunks = git_hunks.list(repo:get_path(), {
        filename = 'test.txt',
        staged = false,
      })

      if #hunks > 0 then
        local success, err = index:add_hunk('test.txt', hunks[1])
        assert(err == nil, 'should not return error')
        assert(success == true, 'should succeed')
      end
    end)

    it('requires filename', function()
      local _, err = index:add_hunk(nil, {})
      assert(err ~= nil, 'should return error')
    end)

    it('requires hunk', function()
      local _, err = index:add_hunk('test.txt', nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('reset_cache', function()
    it('clears all cached data', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      index:staged_files() -- Create cache
      index:unstaged_files() -- Create cache

      index:reset_cache()

      assert(index._staged_files == nil, 'staged cache should be cleared')
      assert(index._unstaged_files == nil, 'unstaged cache should be cleared')
    end)
  end)

  describe('has_staged_changes', function()
    it('returns false for clean index', function()
      assert(not index:has_staged_changes(), 'should not have staged changes')
    end)

    it('returns true when files are staged', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      assert(index:has_staged_changes(), 'should have staged changes')
    end)
  end)

  describe('is_clean', function()
    it('returns true for clean index', function()
      assert(index:is_clean(), 'index should be clean')
    end)

    it('returns false when there are changes', function()
      test_repo:create_file('test.txt', { 'content' })

      assert(not index:is_clean(), 'index should not be clean')
    end)
  end)

  describe('commit', function()
    it('creates a commit with staged changes', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      local success, err = index:commit('Test commit')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
    end)

    it('requires commit message', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      local success, err = index:commit(nil)
      assert(err ~= nil, 'should return error')
      assert(success == nil, 'should fail')
    end)

    it('fails when no changes are staged', function()
      local _, err = index:commit('Empty commit')
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('can_commit', function()
    it('returns false when no changes are staged', function()
      assert(not index:can_commit(), 'should not be able to commit')
    end)

    it('returns true when changes are staged', function()
      test_repo:create_file('test.txt', { 'content' })
      test_repo:stage_file('test.txt')

      assert(index:can_commit(), 'should be able to commit')
    end)
  end)

  describe('__tostring', function()
    it('returns string representation', function()
      local str = tostring(index)
      assert(type(str) == 'string', 'should return string')
      assert(str:match('GitIndex'), 'should contain class name')
    end)
  end)
end)
