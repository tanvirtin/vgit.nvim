local GitTree = require('vgit.git.GitTree')
local git_log = require('vgit.git.git_log')

describe('GitTree', function()
  local function make_repo(path)
    return { get_path = function() return path end }
  end

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitTree(nil, 'HEAD')
      end, 'GitTree requires a repository')
    end)

    it('should error when commit is nil', function()
      assert.has_error(function()
        GitTree(make_repo('/repo'), nil)
      end, 'GitTree requires a commit reference')
    end)

    it('should create with valid arguments', function()
      local tree = GitTree(make_repo('/repo'), 'HEAD')
      assert.is_not_nil(tree)
    end)
  end)

  describe('ref', function()
    it('should return the commit reference', function()
      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.are.equal('abc123', tree:ref())
    end)

    it('should return HEAD when HEAD was passed', function()
      local tree = GitTree(make_repo('/repo'), 'HEAD')
      assert.are.equal('HEAD', tree:ref())
    end)
  end)

  describe('reset', function()
    it('should clear all cached fields', function()
      local tree = GitTree(make_repo('/repo'), 'HEAD')
      -- Manually set cached fields to non-nil values
      tree._commit_data = { some = 'data' }
      tree._parent_tree = { some = 'tree' }
      tree._files = { 'file1' }
      tree._stats = { files_changed = 1 }
      tree._author = { name = 'Alice' }
      tree._timestamp = 12345
      tree._message = 'hello'

      tree:reset()

      assert.is_nil(tree._commit_data)
      assert.is_nil(tree._parent_tree)
      assert.is_nil(tree._files)
      assert.is_nil(tree._stats)
      assert.is_nil(tree._author)
      assert.is_nil(tree._timestamp)
      assert.is_nil(tree._message)
    end)
  end)

  describe('is_merge', function()
    local original_get

    before_each(function()
      original_get = git_log.get
    end)

    after_each(function()
      git_log.get = original_get
    end)

    it('should return true when parent_hash contains a space (merge commit)', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456 ghi789',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'Merge branch main',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.is_true(tree:is_merge())
    end)

    it('should return false when parent_hash has no space (regular commit)', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'Regular commit',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.is_false(tree:is_merge())
    end)

    it('should return false when parent_hash is empty (initial commit)', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = '',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'Initial commit',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.is_false(tree:is_merge())
    end)

    it('should return false when parent_hash is nil (initial commit)', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = nil,
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'Initial commit',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.is_false(tree:is_merge())
    end)

    it('should return false on error', function()
      git_log.get = function()
        return nil, { 'git error' }
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      assert.is_false(tree:is_merge())
    end)
  end)

  describe('commit caching', function()
    local original_get

    before_each(function()
      original_get = git_log.get
    end)

    after_each(function()
      git_log.get = original_get
    end)

    it('should cache commit data after first fetch', function()
      local call_count = 0
      git_log.get = function()
        call_count = call_count + 1
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'test',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      tree:commit()
      tree:commit()
      assert.are.equal(1, call_count)
    end)

    it('should re-fetch after reset', function()
      local call_count = 0
      git_log.get = function()
        call_count = call_count + 1
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'test',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      tree:commit()
      tree:reset()
      tree:commit()
      assert.are.equal(2, call_count)
    end)
  end)

  describe('author', function()
    local original_get

    before_each(function()
      original_get = git_log.get
    end)

    after_each(function()
      git_log.get = original_get
    end)

    it('should return author name and email', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'test',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      local author, err = tree:author()
      assert.is_nil(err)
      assert.are.equal('Alice', author.name)
      assert.are.equal('alice@test.com', author.email)
    end)

    it('should cache author data', function()
      local call_count = 0
      git_log.get = function()
        call_count = call_count + 1
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'test',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      tree:author()
      tree:author()
      assert.are.equal(1, call_count)
    end)
  end)

  describe('timestamp', function()
    local original_get

    before_each(function()
      original_get = git_log.get
    end)

    after_each(function()
      git_log.get = original_get
    end)

    it('should return numeric timestamp', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'test',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      local ts, err = tree:timestamp()
      assert.is_nil(err)
      assert.are.equal(1700000000, ts)
    end)
  end)

  describe('message', function()
    local original_get

    before_each(function()
      original_get = git_log.get
    end)

    after_each(function()
      git_log.get = original_get
    end)

    it('should return commit summary', function()
      git_log.get = function()
        return {
          commit_hash = 'abc123',
          parent_hash = 'def456',
          author_name = 'Alice',
          author_email = 'alice@test.com',
          timestamp = '1700000000',
          summary = 'fix: important bug fix',
        }, nil
      end

      local tree = GitTree(make_repo('/repo'), 'abc123')
      local msg, err = tree:message()
      assert.is_nil(err)
      assert.are.equal('fix: important bug fix', msg)
    end)
  end)
end)
