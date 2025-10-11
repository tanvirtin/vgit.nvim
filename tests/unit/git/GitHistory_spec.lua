local test_harness = require('ops.lib.test_harness')
local git_test_repo = require('tests.helpers.git_test_repo')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitHistory', function()
  local test_repo
  local repo

  before_each(function()
    test_repo = git_test_repo.create()
    test_repo:init()

    -- Create multiple commits
    test_repo:create_file('file1.txt', { 'content 1' })
    test_repo:stage_file('file1.txt')
    test_repo:commit('First commit')

    test_repo:create_file('file2.txt', { 'content 2' })
    test_repo:stage_file('file2.txt')
    test_repo:commit('Second commit')

    test_repo:create_file('file3.txt', { 'content 3' })
    test_repo:stage_file('file3.txt')
    test_repo:commit('Third commit')

    repo = GitRepository.open(test_repo.dir)
  end)

  after_each(function()
    if test_repo then test_repo:cleanup() end
  end)

  describe('constructor', function()
    it('creates history', function()
      local history = repo:history()
      assert(history ~= nil, 'history should be created')
    end)

    it('requires repository', function()
      local GitHistory = require('vgit.git.GitHistory')
      local success = pcall(function()
        GitHistory(nil)
      end)
      assert(not success, 'should require repository')
    end)

    it('accepts options', function()
      local history = repo:history({ count = 5, path = 'file1.txt' })
      assert(history ~= nil, 'history should be created')
      assert(history._count == 5, 'should have correct count')
      assert(history._path == 'file1.txt', 'should have correct path')
    end)
  end)

  describe('commits', function()
    it('returns all commits', function()
      local history = repo:history()
      local commits, err = history:commits()
      assert(err == nil, 'should not return error')
      assert(type(commits) == 'table', 'should return table')
      assert(#commits == 3, 'should have 3 commits')
    end)

    it('caches commits', function()
      local history = repo:history()
      local commits1, _ = history:commits()
      local commits2, _ = history:commits()
      assert(commits1 == commits2, 'should return cached data')
    end)

    it('respects count limit', function()
      local history = repo:history({ count = 2 })
      local commits, err = history:commits()
      assert(err == nil, 'should not return error')
      assert(#commits == 2, 'should have 2 commits')
    end)
  end)

  describe('first', function()
    it('returns most recent commit', function()
      local history = repo:history()
      local commit, err = history:first()
      assert(err == nil, 'should not return error')
      assert(commit ~= nil, 'commit should be returned')
      assert(commit.summary == 'Third commit', 'should be most recent')
    end)
  end)

  describe('last', function()
    it('returns oldest commit', function()
      local history = repo:history()
      local commit, err = history:last()
      assert(err == nil, 'should not return error')
      assert(commit ~= nil, 'commit should be returned')
      assert(commit.summary == 'First commit', 'should be oldest')
    end)
  end)

  describe('count', function()
    it('returns commit count', function()
      local history = repo:history()
      local count, err = history:count()
      assert(err == nil, 'should not return error')
      assert(count == 3, 'should have 3 commits')
    end)
  end)

  describe('is_empty', function()
    it('returns false when commits exist', function()
      local history = repo:history()
      assert(not history:is_empty(), 'should not be empty')
    end)
  end)

  describe('search', function()
    it('finds commits by pattern', function()
      local history = repo:history()
      local found, err = history:search('Second')
      assert(err == nil, 'should not return error')
      assert(#found == 1, 'should find 1 commit')
      assert(found[1].summary == 'Second commit', 'should find correct commit')
    end)

    it('returns empty for no matches', function()
      local history = repo:history()
      local found, err = history:search('NonExistent')
      assert(err == nil, 'should not return error')
      assert(#found == 0, 'should find no commits')
    end)
  end)

  describe('authors', function()
    it('returns unique authors', function()
      local history = repo:history()
      local authors, err = history:authors()
      assert(err == nil, 'should not return error')
      assert(type(authors) == 'table', 'should return table')
      assert(#authors > 0, 'should have authors')
      assert(authors[1].name ~= nil, 'author should have name')
      assert(authors[1].email ~= nil, 'author should have email')
    end)
  end)

  describe('iter', function()
    it('iterates over commits', function()
      local history = repo:history()
      local count = 0
      for i, commit in history:iter() do
        count = count + 1
        assert(i == count, 'index should match count')
        assert(commit ~= nil, 'commit should exist')
      end
      assert(count == 3, 'should iterate over 3 commits')
    end)
  end)

  describe('reset', function()
    it('clears cached data', function()
      local history = repo:history()
      history:commits() -- Create cache

      history:reset()

      assert(history._commits == nil, 'commits cache should be cleared')
    end)
  end)

  describe('__tostring', function()
    it('returns string representation', function()
      local history = repo:history()
      local str = tostring(history)
      assert(type(str) == 'string', 'should return string')
      assert(str:match('GitHistory'), 'should contain class name')
    end)
  end)
end)
