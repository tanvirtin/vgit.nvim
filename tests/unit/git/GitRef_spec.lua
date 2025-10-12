local test_harness = require('ops.lib.test_harness')
local git_test_repo = require('tests.helpers.git_test_repo')
local GitRepository = require('vgit.git.GitRepository')

local describe = test_harness.describe
local it = test_harness.it
local before_each = test_harness.before_each
local after_each = test_harness.after_each

describe('GitRef', function()
  local test_repo
  local repo
  local refs

  before_each(function()
    test_repo = git_test_repo.create()
    test_repo:init()

    -- Create initial commit
    test_repo:create_file('file1.txt', { 'initial content' })
    test_repo:stage_file('file1.txt')
    test_repo:commit('Initial commit')

    repo = GitRepository.open(test_repo.dir)
    refs = repo:refs()
  end)

  after_each(function()
    if test_repo then test_repo:cleanup() end
  end)

  describe('constructor', function()
    it('creates refs manager', function()
      assert(refs ~= nil, 'refs should be created')
      assert(refs:repository() == repo, 'should have repository reference')
    end)

    it('requires repository', function()
      local GitRef = require('vgit.git.GitRef')
      local success = pcall(function()
        GitRef(nil)
      end)
      assert(not success, 'should require repository')
    end)
  end)

  describe('current', function()
    it('returns current branch', function()
      local current, err = refs:current()
      assert(err == nil, 'should not return error')
      assert(current ~= nil, 'current should be returned')
      assert(current.name ~= nil, 'should have name')
      assert(current.hash ~= nil, 'should have hash')
    end)

    it('detects detached HEAD', function()
      local current, _ = refs:current()
      -- On initial setup, should not be detached
      assert(current.is_detached ~= nil, 'should have is_detached field')
    end)
  end)

  describe('current_branch', function()
    it('returns branch name', function()
      local name, err = refs:current_branch()
      assert(err == nil, 'should not return error')
      assert(type(name) == 'string', 'name should be string')
    end)
  end)

  describe('head', function()
    it('returns HEAD hash', function()
      local hash, err = refs:head()
      assert(err == nil, 'should not return error')
      assert(type(hash) == 'string', 'hash should be string')
      assert(#hash == 40, 'hash should be 40 characters')
    end)
  end)

  describe('branches', function()
    it('lists branches', function()
      local branches, err = refs:branches()
      assert(err == nil, 'should not return error')
      assert(type(branches) == 'table', 'should return table')
    end)
  end)

  describe('tags', function()
    it('returns empty list when no tags', function()
      local tags, err = refs:tags()
      assert(err == nil, 'should not return error')
      assert(type(tags) == 'table', 'should return table')
    end)
  end)

  describe('remote_branches', function()
    it('returns empty list when no remotes', function()
      local remote_branches, err = refs:remote_branches()
      assert(err == nil, 'should not return error')
      assert(type(remote_branches) == 'table', 'should return table')
    end)
  end)

  describe('create_branch', function()
    it('creates a new branch', function()
      local success, err = refs:create_branch('feature/test')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(refs:branch_exists('feature/test'), 'branch should exist')
    end)

    it('creates branch from specific commit', function()
      -- Create second commit to have a ref
      test_repo:create_file('file2.txt', { 'content' })
      test_repo:stage_file('file2.txt')
      test_repo:commit('Second commit')

      local head_hash, _ = refs:head()
      local success, err = refs:create_branch('from-commit', head_hash)
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
    end)

    it('requires branch name', function()
      local _, err = refs:create_branch(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('delete_branch', function()
    it('deletes a branch', function()
      refs:create_branch('temp-branch')

      local success, err = refs:delete_branch('temp-branch')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(not refs:branch_exists('temp-branch'), 'branch should not exist')
    end)

    it('requires branch name', function()
      local _, err = refs:delete_branch(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('checkout', function()
    it('checks out a branch', function()
      refs:create_branch('test-branch')

      local success, err = refs:checkout('test-branch')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      local current_name, _ = refs:current_branch()
      assert(current_name == 'test-branch', 'should be on new branch')
    end)

    it('requires ref name', function()
      local _, err = refs:checkout(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('checkout_new_branch', function()
    it('creates and checks out a branch', function()
      local success, err = refs:checkout_new_branch('new-feature')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')

      assert(refs:branch_exists('new-feature'), 'branch should exist')
      local current_name, _ = refs:current_branch()
      assert(current_name == 'new-feature', 'should be on new branch')
    end)

    it('requires branch name', function()
      local _, err = refs:checkout_new_branch(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('create_tag', function()
    it('creates a lightweight tag', function()
      local success, err = refs:create_tag('v1.0.0')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(refs:tag_exists('v1.0.0'), 'tag should exist')
    end)

    it('creates an annotated tag', function()
      local success, err = refs:create_tag('v1.1.0', 'HEAD', 'Release v1.1.0')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(refs:tag_exists('v1.1.0'), 'tag should exist')
    end)

    it('requires tag name', function()
      local _, err = refs:create_tag(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('delete_tag', function()
    it('deletes a tag', function()
      refs:create_tag('temp-tag')

      local success, err = refs:delete_tag('temp-tag')
      assert(err == nil, 'should not return error')
      assert(success == true, 'should succeed')
      assert(not refs:tag_exists('temp-tag'), 'tag should not exist')
    end)

    it('requires tag name', function()
      local _, err = refs:delete_tag(nil)
      assert(err ~= nil, 'should return error')
    end)
  end)

  describe('branch_exists', function()
    it('returns true for existing branch', function()
      -- Get current branch name
      local current, _ = refs:current()
      assert(refs:branch_exists(current.name), 'current branch should exist')
    end)

    it('returns false for non-existing branch', function()
      assert(not refs:branch_exists('nonexistent-branch'), 'should not exist')
    end)
  end)

  describe('tag_exists', function()
    it('returns false for non-existing tag', function()
      assert(not refs:tag_exists('v1.0.0'), 'tag should not exist')
    end)
  end)

  describe('reset_cache', function()
    it('clears cached data', function()
      refs:current() -- Create cache
      refs:branches() -- Create cache
      refs:tags() -- Create cache

      refs:reset_cache()

      assert(refs._current == nil, 'current cache should be cleared')
      assert(refs._branches == nil, 'branches cache should be cleared')
      assert(refs._tags == nil, 'tags cache should be cleared')
    end)
  end)
end)
