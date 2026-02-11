local GitTree = require('vgit.git.GitTree')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

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

  describe('integration', function()
    local repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = {
          ['file1.txt'] = { 'initial content' },
        },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
    end)

    describe('is_merge', function()
      it('should return false for regular commit', function()
        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'second content' } },
          message = 'Regular commit',
        })

        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        assert.is_false(tree:is_merge())
      end)

      it('should return false for initial commit', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        assert.is_false(tree:is_merge())
      end)
    end)

    describe('commit caching', function()
      it('should cache commit data after first fetch', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local data1, err1 = tree:commit()
        assert(not err1, 'First commit() call failed: ' .. tostring(err1))
        assert.is_not_nil(data1)

        local data2, err2 = tree:commit()
        assert(not err2, 'Second commit() call failed: ' .. tostring(err2))
        assert.is_not_nil(data2)

        -- Both calls should return the exact same table reference (cached)
        assert.are.equal(data1, data2)
      end)

      it('should re-fetch after reset', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local data1, err1 = tree:commit()
        assert(not err1, 'First commit() call failed: ' .. tostring(err1))
        assert.is_not_nil(data1)

        tree:reset()

        local data2, err2 = tree:commit()
        assert(not err2, 'Second commit() call failed: ' .. tostring(err2))
        assert.is_not_nil(data2)

        -- After reset, a new object should be fetched (different table reference)
        -- Note: GitCommit defines __eq by hash, so use rawequal to check table identity
        assert.is_false(rawequal(data1, data2))
        -- But the data should be equivalent
        eq(data1.commit_hash, data2.commit_hash)
      end)
    end)

    describe('author', function()
      it('should return author name and email', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local author, err = tree:author()
        assert(not err, 'author() failed: ' .. tostring(err))

        eq('Test User', author.name)
        eq('test@example.com', author.email)
      end)

      it('should cache author data', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local author1, err1 = tree:author()
        assert(not err1, 'First author() call failed: ' .. tostring(err1))

        local author2, err2 = tree:author()
        assert(not err2, 'Second author() call failed: ' .. tostring(err2))

        -- Both calls should return the exact same table reference (cached)
        assert.are.equal(author1, author2)
      end)
    end)

    describe('timestamp', function()
      it('should return numeric timestamp', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local ts, err = tree:timestamp()
        assert(not err, 'timestamp() failed: ' .. tostring(err))

        assert.are.equal('number', type(ts))
        assert.is_true(ts > 0)
      end)
    end)

    describe('message', function()
      it('should return commit summary', function()
        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'second content' } },
          message = 'fix: important bug fix',
        })

        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local msg, err = tree:message()
        assert(not err, 'message() failed: ' .. tostring(err))

        eq('fix: important bug fix', msg)
      end)

    end)

    describe('hash', function()
      it('should return the full commit hash', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        local hash, err = tree:hash()
        assert(not err, 'hash() failed: ' .. tostring(err))
        eq(commit_hash, hash)
      end)
    end)

    describe('parent_hash', function()
      it('should return the parent commit hash', function()
        local first_commit = test_repo.get_head_commit(repo)

        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'second content' } },
          message = 'Second commit',
        })

        local second_commit = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), second_commit)

        local parent, err = tree:parent_hash()
        assert(not err, 'parent_hash() failed: ' .. tostring(err))
        eq(first_commit, parent)
      end)
    end)

    describe('parent', function()
      it('should error due to self._repository being nil', function()
        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'second content' } },
          message = 'Second commit',
        })

        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        -- parent() references self._repository which is never set
        -- (constructor stores _repo_path as a string)
        local ok, _ = pcall(function()
          return tree:parent()
        end)
        assert.is_false(ok)
      end)
    end)

    describe('is_initial', function()
      it('should return true for the first commit', function()
        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        assert.is_true(tree:is_initial())
      end)

      it('should return false for non-initial commit', function()
        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'second content' } },
          message = 'Second commit',
        })

        local commit_hash = test_repo.get_head_commit(repo)
        local tree = GitTree(make_repo(repo), commit_hash)

        assert.is_false(tree:is_initial())
      end)
    end)
  end)
end)
