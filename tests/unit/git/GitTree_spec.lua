local test_harness = require('ops.lib.test_harness')
local git_test_repo = require('tests.helpers.git_test_repo')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitTree', function()
  local test_repo
  local repo

  before_each(function()
    test_repo = git_test_repo.create()
    test_repo:init()

    -- Create initial commit
    test_repo:create_file('file1.txt', { 'initial content' })
    test_repo:stage_file('file1.txt')
    test_repo:commit('Initial commit')

    repo = GitRepository.open(test_repo.dir)
  end)

  after_each(function()
    if test_repo then test_repo:cleanup() end
  end)

  describe('constructor', function()
    it('creates a tree for HEAD', function()
      local tree = repo:tree('HEAD')
      assert(tree ~= nil, 'tree should be created')
      assert(tree:ref() == 'HEAD', 'should have correct ref')
    end)

    it('requires repository', function()
      local GitTree = require('vgit.git.GitTree')
      local success = pcall(function()
        GitTree(nil, 'HEAD')
      end)
      assert(not success, 'should require repository')
    end)

    it('requires commit reference', function()
      local GitTree = require('vgit.git.GitTree')
      local success = pcall(function()
        GitTree(repo, nil)
      end)
      assert(not success, 'should require commit')
    end)
  end)

  describe('commit', function()
    it('fetches commit data', function()
      local tree = repo:tree('HEAD')
      local commit, err = tree:commit()
      assert(err == nil, 'should not return error')
      assert(commit ~= nil, 'commit should be fetched')
      assert(commit.commit_hash ~= nil, 'should have hash')
    end)

    it('caches commit data', function()
      local tree = repo:tree('HEAD')
      local commit1, _ = tree:commit()
      local commit2, _ = tree:commit()
      assert(commit1 == commit2, 'should return cached data')
    end)
  end)

  describe('hash', function()
    it('returns commit hash', function()
      local tree = repo:tree('HEAD')
      local hash, err = tree:hash()
      assert(err == nil, 'should not return error')
      assert(type(hash) == 'string', 'hash should be string')
      assert(#hash == 40, 'hash should be 40 characters')
    end)
  end)

  describe('parent', function()
    it('returns parent tree', function()
      -- Create second commit
      test_repo:create_file('file2.txt', { 'second file' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Second commit')

      local tree = repo:tree('HEAD')
      local parent, err = tree:parent()
      assert(err == nil, 'should not return error')
      assert(parent ~= nil, 'parent should exist')
      assert(parent:ref() ~= 'HEAD', 'parent should have different ref')
    end)

    it('returns error for initial commit', function()
      local tree = repo:tree('HEAD')
      local _, err = tree:parent()
      assert(err ~= nil, 'should return error for initial commit')
    end)
  end)

  describe('author', function()
    it('returns author information', function()
      local tree = repo:tree('HEAD')
      local author, err = tree:author()
      assert(err == nil, 'should not return error')
      assert(author ~= nil, 'author should be returned')
      assert(author.name ~= nil, 'should have name')
      assert(author.email ~= nil, 'should have email')
    end)
  end)

  describe('message', function()
    it('returns commit message', function()
      local tree = repo:tree('HEAD')
      local message, err = tree:message()
      assert(err == nil, 'should not return error')
      assert(message == 'Initial commit', 'should have correct message')
    end)
  end)

  describe('file', function()
    it('returns file content at commit', function()
      local tree = repo:tree('HEAD')
      local lines, err = tree:file('file1.txt')
      assert(err == nil, 'should not return error')
      assert(type(lines) == 'table', 'should return lines')
      assert(lines[1] == 'initial content', 'should have correct content')
    end)

    it('requires filename', function()
      local tree = repo:tree('HEAD')
      local _, err = tree:file(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('has_file', function()
    it('returns true for existing file', function()
      local tree = repo:tree('HEAD')
      local has_file, err = tree:has_file('file1.txt')
      assert(err == nil, 'should not return error')
      assert(has_file == true, 'file should exist')
    end)

    it('returns false for non-existing file', function()
      local tree = repo:tree('HEAD')
      local has_file, err = tree:has_file('nonexistent.txt')
      assert(err == nil, 'should not return error')
      assert(has_file == false, 'file should not exist')
    end)
  end)

  describe('files', function()
    it('returns changed files in commit', function()
      -- Create second commit
      test_repo:create_file('file2.txt', { 'second file' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Add file2')

      local tree = repo:tree('HEAD')
      local files, err = tree:files()
      assert(err == nil, 'should not return error')
      assert(type(files) == 'table', 'should return table')
      assert(#files > 0, 'should have files')
    end)
  end)

  describe('is_initial', function()
    it('returns true for initial commit', function()
      local tree = repo:tree('HEAD')
      assert(tree:is_initial(), 'should be initial commit')
    end)

    it('returns false for non-initial commit', function()
      -- Create second commit
      test_repo:create_file('file2.txt', { 'second file' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Second commit')

      local tree = repo:tree('HEAD')
      assert(not tree:is_initial(), 'should not be initial commit')
    end)
  end)

  describe('diff', function()
    it('returns diff between trees', function()
      -- Create second commit
      test_repo:create_file('file2.txt', { 'second file' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Second commit')

      local current_tree = repo:tree('HEAD')
      local parent_tree, _ = current_tree:parent()

      if parent_tree then
        local hunks, err = current_tree:diff(parent_tree)
        assert(err == nil, 'should not return error')
        assert(type(hunks) == 'table', 'should return table')
      end
    end)

    it('requires other tree', function()
      local tree = repo:tree('HEAD')
      local _, err = tree:diff(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('stats', function()
    it('returns commit statistics', function()
      -- Create second commit with changes
      test_repo:create_file('file2.txt', { 'line 1', 'line 2', 'line 3' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Second commit')

      local tree = repo:tree('HEAD')
      local stats, err = tree:stats()
      assert(err == nil, 'should not return error')
      assert(stats ~= nil, 'stats should be returned')
      assert(type(stats.files_changed) == 'number', 'should have files_changed')
      assert(type(stats.insertions) == 'number', 'should have insertions')
      assert(type(stats.deletions) == 'number', 'should have deletions')
    end)
  end)

  describe('is_merge', function()
    it('returns false for normal commit', function()
      local tree = repo:tree('HEAD')
      local is_merge, err = tree:is_merge()
      assert(err == nil, 'should not return error')
      assert(is_merge == false, 'initial commit should not be merge')
    end)
  end)

  describe('reset', function()
    it('clears cached data', function()
      local tree = repo:tree('HEAD')
      tree:commit() -- Create cache
      tree:files() -- Create cache

      tree:reset()

      assert(tree._commit_data == nil, 'commit cache should be cleared')
      assert(tree._files == nil, 'files cache should be cleared')
    end)
  end)
end)
