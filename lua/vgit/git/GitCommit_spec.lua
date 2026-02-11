local GitCommit = require('vgit.git.GitCommit')

local eq = assert.are.same

describe('GitCommit:', function()
  describe('constructor', function()
    it('should create a commit with all metadata', function()
      local commit = GitCommit({
        hash = 'abc1234567890',
        parent_hash = 'def0987654321',
        author = 'John Doe',
        author_mail = 'john@example.com',
        author_time = 1234567890,
        author_tz = '+0000',
        committer = 'Jane Smith',
        committer_mail = 'jane@example.com',
        committer_time = 1234567900,
        committer_tz = '+0000',
        message = 'Initial commit',
      })

      eq(commit.hash, 'abc1234567890')
      eq(commit.parent_hash, 'def0987654321')
      eq(commit.author, 'John Doe')
      eq(commit.author_mail, 'john@example.com')
      eq(commit.author_time, 1234567890)
      eq(commit.author_tz, '+0000')
      eq(commit.committer, 'Jane Smith')
      eq(commit.committer_mail, 'jane@example.com')
      eq(commit.committer_time, 1234567900)
      eq(commit.committer_tz, '+0000')
      eq(commit.message, 'Initial commit')
    end)

    it('should accept commit_hash as alias for hash', function()
      local commit = GitCommit({
        commit_hash = 'abc1234',
        author = 'Test',
        author_time = 1234567890,
      })

      eq(commit.hash, 'abc1234')
    end)

    it('should accept commit_message as alias for message', function()
      local commit = GitCommit({
        hash = 'abc1234',
        commit_message = 'Test message',
      })

      eq(commit.message, 'Test message')
    end)

    it('should generate an id if not provided', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      assert.is_string(commit.id)
      assert.is_true(#commit.id > 0)
    end)

    it('should use provided id', function()
      local commit = GitCommit({
        id = 'custom-id',
        hash = 'abc1234',
      })

      eq(commit.id, 'custom-id')
    end)

    it('should error if no data provided', function()
      assert.has_error(function()
        GitCommit()
      end, 'GitCommit requires data')
    end)
  end)

  describe('is_empty', function()
    it('should return true for empty commit hash', function()
      local commit = GitCommit({
        hash = '0000000000000000000000000000000000000000',
      })

      assert.is_true(commit:is_empty())
    end)

    it('should return false for normal commit hash', function()
      local commit = GitCommit({
        hash = 'abc1234567890',
      })

      assert.is_false(commit:is_empty())
    end)
  end)

  describe('is_uncommitted', function()
    it('should return true for empty commit hash', function()
      local commit = GitCommit({
        hash = GitCommit.EMPTY_HASH,
      })

      assert.is_true(commit:is_uncommitted())
    end)

    it('should return false for normal commit hash', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      assert.is_false(commit:is_uncommitted())
    end)
  end)

  describe('is_committed', function()
    it('should return false for empty commit hash', function()
      local commit = GitCommit({
        hash = GitCommit.EMPTY_HASH,
      })

      assert.is_false(commit:is_committed())
    end)

    it('should return true for normal commit hash', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      assert.is_true(commit:is_committed())
    end)
  end)

  describe('short_hash', function()
    it('should return first 7 characters by default', function()
      local commit = GitCommit({
        hash = 'abc1234567890',
      })

      eq(commit:short_hash(), 'abc1234')
    end)

    it('should return custom length', function()
      local commit = GitCommit({
        hash = 'abc1234567890',
      })

      eq(commit:short_hash(5), 'abc12')
      eq(commit:short_hash(10), 'abc1234567')
    end)

    it('should return nil if no hash', function()
      local commit = GitCommit({})

      eq(commit:short_hash(), nil)
    end)
  end)

  describe('age', function()
    it('should return age from author_time', function()
      local commit = GitCommit({
        hash = 'abc1234',
        author_time = os.time() - 3600, -- 1 hour ago
      })

      local age = commit:age()
      assert.is_table(age)
      assert.is_string(age.display)
    end)

    it('should return nil if no author_time', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      eq(commit:age(), nil)
    end)
  end)

  describe('author_signature', function()
    it('should return author with email', function()
      local commit = GitCommit({
        hash = 'abc1234',
        author = 'John Doe',
        author_mail = 'john@example.com',
      })

      eq(commit:author_signature(), 'John Doe <john@example.com>')
    end)

    it('should return author without email', function()
      local commit = GitCommit({
        hash = 'abc1234',
        author = 'John Doe',
      })

      eq(commit:author_signature(), 'John Doe')
    end)

    it('should return nil if no author', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      eq(commit:author_signature(), nil)
    end)
  end)

  describe('committer_signature', function()
    it('should return committer with email', function()
      local commit = GitCommit({
        hash = 'abc1234',
        committer = 'Jane Smith',
        committer_mail = 'jane@example.com',
      })

      eq(commit:committer_signature(), 'Jane Smith <jane@example.com>')
    end)

    it('should return committer without email', function()
      local commit = GitCommit({
        hash = 'abc1234',
        committer = 'Jane Smith',
      })

      eq(commit:committer_signature(), 'Jane Smith')
    end)

    it('should return nil if no committer', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      eq(commit:committer_signature(), nil)
    end)
  end)

  describe('summary', function()
    it('should return first line of commit message', function()
      local commit = GitCommit({
        hash = 'abc1234',
        message = 'First line\nSecond line\nThird line',
      })

      eq(commit.summary, 'First line')
    end)

    it('should return message if single line', function()
      local commit = GitCommit({
        hash = 'abc1234',
        message = 'Single line message',
      })

      eq(commit.summary, 'Single line message')
    end)

    it('should return nil if no message', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      eq(commit.summary, nil)
    end)
  end)

  describe('__eq', function()
    it('should return true for commits with same hash', function()
      local commit1 = GitCommit({
        hash = 'abc1234',
        author = 'John Doe',
      })

      local commit2 = GitCommit({
        hash = 'abc1234',
        author = 'Jane Smith',
      })

      assert.is_true(commit1 == commit2)
    end)

    it('should return false for commits with different hash', function()
      local commit1 = GitCommit({
        hash = 'abc1234',
      })

      local commit2 = GitCommit({
        hash = 'def5678',
      })

      assert.is_false(commit1 == commit2)
    end)
  end)

  describe('has_parent', function()
    it('should return true when parent_hash is set', function()
      local commit = GitCommit({
        hash = 'abc1234',
        parent_hash = 'def5678',
      })

      assert.is_true(commit:has_parent())
    end)

    it('should return false when parent_hash is nil', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      assert.is_false(commit:has_parent())
    end)

    it('should return false when parent_hash is empty string', function()
      local commit = GitCommit({
        hash = 'abc1234',
        parent_hash = '',
      })

      assert.is_false(commit:has_parent())
    end)
  end)

  describe('parent', function()
    it('should return nil when no parent_hash', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local parent, err = commit:parent()
      assert.is_nil(parent)
      assert.is_nil(err)
    end)
  end)

  describe('traverse', function()
    it('should return error when callback is nil', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local result, err = commit:traverse(nil)
      assert.is_nil(result)
      assert.is_not_nil(err)
    end)

    it('should call callback with the commit at depth 0', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local visited = {}
      commit:traverse(function(c, depth)
        table.insert(visited, { hash = c.hash, depth = depth })
      end)

      eq(1, #visited)
      eq('abc1234', visited[1].hash)
      eq(0, visited[1].depth)
    end)

    it('should stop when callback returns false', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local count = 0
      commit:traverse(function(c, depth)
        count = count + 1
        return false
      end)

      eq(1, count)
    end)

    it('should respect max_depth', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local count = 0
      commit:traverse(function(c, depth)
        count = count + 1
      end, 0)

      eq(0, count)
    end)
  end)

  describe('ancestor', function()
    it('should return self for depth 0', function()
      local commit = GitCommit({
        hash = 'abc1234',
      })

      local result, err = commit:ancestor(0)
      assert.is_nil(err)
      eq('abc1234', result.hash)
    end)
  end)

  describe('EMPTY_HASH constant', function()
    it('should be 40 zero characters', function()
      eq(GitCommit.EMPTY_HASH, '0000000000000000000000000000000000000000')
      eq(#GitCommit.EMPTY_HASH, 40)
    end)
  end)

  describe('blame context', function()
    it('should support commits with blame context', function()
      local commit = GitCommit({
        hash = 'abc123',
        author = 'John Doe',
        author_time = 1234567890,
        message = 'Fix bug',
        context = {
          lnum = 42,
          filename = 'parser.lua',
        },
      })

      eq(commit.lnum, 42)
      eq(commit.filename, 'parser.lua')
    end)

    it('should support revision context', function()
      local commit = GitCommit({
        hash = 'abc123',
        author = 'Test',
        message = 'Test',
        context = {
          revision = 'HEAD~5',
        },
      })

      eq(commit.revision, 'HEAD~5')
    end)
  end)
end)
