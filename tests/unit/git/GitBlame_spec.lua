local GitBlame = require('vgit.git.GitBlame')

local eq = assert.are.same

describe('GitBlame:', function()
  describe('constructor', function()
    it('should parse blame info into structured data', function()
      local info = {
        'abc1234 5',
        'author John Doe',
        'author-mail john@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Jane Smith',
        'committer-mail jane@example.com',
        'committer-time 1234567900',
        'committer-tz +0000',
        'summary Initial commit',
      }

      local blame = GitBlame(info)

      eq(blame.lnum, 5)
      eq(blame.commit_hash, 'abc1234')
      eq(blame.author, 'John Doe')
      eq(blame.author_mail, 'john@example.com')
      eq(blame.author_time, 1234567890)
      eq(blame.author_tz, '+0000')
      eq(blame.committer, 'Jane Smith')
      eq(blame.committer_mail, 'jane@example.com')
      eq(blame.committer_time, 1234567900)
      eq(blame.committer_tz, '+0000')
      eq(blame.commit_message, 'Initial commit')
      eq(blame.committed, true)
    end)

    it('should strip angle brackets from author email', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail <test@example.com>',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail <test@example.com>',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      eq(blame.author_mail, 'test@example.com')
      eq(blame.committer_mail, 'test@example.com')
    end)

    it('should handle email without angle brackets', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      eq(blame.author_mail, 'test@example.com')
      eq(blame.committer_mail, 'test@example.com')
    end)

    it('should detect uncommitted changes', function()
      local info = {
        '0000000000000000000000000000000000000000 1',
        'author Not Committed Yet',
        'author-mail not@committed.yet',
        'author-time 0',
        'author-tz +0000',
        'committer Not Committed Yet',
        'committer-mail not@committed.yet',
        'committer-time 0',
        'committer-tz +0000',
        'summary Uncommitted changes',
      }

      local blame = GitBlame(info)

      eq(blame.commit_hash, GitBlame.empty_commit_hash)
      eq(blame.committed, false)
    end)

    it('should parse parent hash when present', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
        'previous def5678 oldfile.txt',
      }

      local blame = GitBlame(info)

      eq(blame.parent_hash, 'def5678')
    end)

    it('should parse filename when present', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
        'filename test.lua',
      }

      local blame = GitBlame(info)

      eq(blame.filename, 'test.lua')
    end)

    it('should convert timestamps to numbers', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567900',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      assert.is_number(blame.author_time)
      assert.is_number(blame.committer_time)
      eq(blame.author_time, 1234567890)
      eq(blame.committer_time, 1234567900)
    end)
  end)

  describe('age', function()
    it('should return age string from author time', function()
      local info = {
        string.format('abc1234 1'),
        'author Test',
        'author-mail test@example.com',
        string.format('author-time %d', os.time() - 3600), -- 1 hour ago
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)
      local age = blame:age()

      assert.is_table(age)
      assert.is_string(age.display)
      assert.is_true(#age.display > 0)
    end)

    it('should handle very recent commits', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        string.format('author-time %d', os.time()), -- Now
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)
      local age = blame:age()

      assert.is_table(age)
      assert.is_string(age.display)
    end)
  end)

  describe('is_uncommitted', function()
    it('should return true for empty commit hash', function()
      local info = {
        '0000000000000000000000000000000000000000 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 0',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 0',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      assert.is_true(blame:is_uncommitted())
    end)

    it('should return false for normal commit hash', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      assert.is_false(blame:is_uncommitted())
    end)
  end)

  describe('is_committed', function()
    it('should return false for empty commit hash', function()
      local info = {
        '0000000000000000000000000000000000000000 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 0',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 0',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      assert.is_false(blame:is_committed())
    end)

    it('should return true for normal commit hash', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      assert.is_true(blame:is_committed())
    end)
  end)

  describe('empty_commit_hash constant', function()
    it('should be 40 zero characters', function()
      eq(GitBlame.empty_commit_hash, '0000000000000000000000000000000000000000')
      eq(#GitBlame.empty_commit_hash, 40)
    end)
  end)

  describe('edge cases', function()
    it('should handle authors with multiple spaces in name', function()
      local info = {
        'abc1234 1',
        'author John Middle Doe',
        'author-mail john@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Jane Middle Smith',
        'committer-mail jane@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Test',
      }

      local blame = GitBlame(info)

      eq(blame.author, 'John Middle Doe')
      eq(blame.committer, 'Jane Middle Smith')
    end)

    it('should handle negative timezones', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz -0500',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz -0800',
        'summary Test',
      }

      local blame = GitBlame(info)

      eq(blame.author_tz, '-0500')
      eq(blame.committer_tz, '-0800')
    end)

    it('should handle multi-line commit messages', function()
      local info = {
        'abc1234 1',
        'author Test',
        'author-mail test@example.com',
        'author-time 1234567890',
        'author-tz +0000',
        'committer Test',
        'committer-mail test@example.com',
        'committer-time 1234567890',
        'committer-tz +0000',
        'summary Multi-line commit message',
      }

      local blame = GitBlame(info)

      eq(blame.commit_message, 'Multi-line commit message')
    end)
  end)
end)
