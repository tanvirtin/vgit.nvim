local GitLog = require('vgit.git.GitLog')

local eq = assert.are.same

describe('GitLog:', function()
  describe('constructor', function()
    it('should parse log line into structured data', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FInitial commitX'
      local log = GitLog(line)

      eq(log.commit_hash, 'abc1234')
      eq(log.parent_hash, 'def5678')
      eq(log.timestamp, '1234567890')
      eq(log.author_name, 'John Doe')
      eq(log.author_email, 'john@example.com')
      eq(log.summary, 'Initial commit')
    end)

    it('should handle multiple parents by taking first', function()
      local line = 'Xabc1234\x1Fdef5678 ghi9012\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FMerge commitX'
      local log = GitLog(line)

      eq(log.commit_hash, 'abc1234')
      eq(log.parent_hash, 'def5678')
    end)

    it('should set revision when revision_count provided', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommit messageX'
      local log = GitLog(line, 5)

      eq(log.revision, 'HEAD~5')
    end)

    it('should not set revision when revision_count is nil', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommit messageX'
      local log = GitLog(line, nil)

      eq(log.revision, nil)
    end)

    it('should handle commit without parent', function()
      local line = 'Xabc1234\x1F\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FInitial commitX'
      local log = GitLog(line)

      eq(log.commit_hash, 'abc1234')
      eq(log.parent_hash, '')
    end)

    it('should handle author with special characters in name', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn O\'Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)

      eq(log.author_name, 'John O\'Doe')
    end)

    it('should handle email with plus addressing', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn+tag@example.com\x1FCommitX'
      local log = GitLog(line)

      eq(log.author_email, 'john+tag@example.com')
    end)

    it('should handle long commit hash', function()
      local line =
        'Xabcdef1234567890abcdef1234567890abcdef12\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)

      eq(log.commit_hash, 'abcdef1234567890abcdef1234567890abcdef12')
    end)

    it('should handle summary with special characters', function()
      local line =
        'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FFix: bug with "quotes" & symbolsX'
      local log = GitLog(line)

      eq(log.summary, 'Fix: bug with "quotes" & symbols')
    end)

    it('should set revision to HEAD~0 when revision_count is 0', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line, 0)

      eq(log.revision, 'HEAD~0')
    end)
  end)

  describe('date', function()
    it('should format timestamp with default format', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)
      local date = log:date()

      assert.is_string(date)
      assert.is_true(#date > 0)
    end)

    it('should format timestamp with custom format', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)
      local date = log:date('%Y-%m-%d')

      assert.is_string(date)
      assert.is_true(#date > 0)
    end)

    it('should handle different date format patterns', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)

      local date_ymd = log:date('%Y-%m-%d')
      local date_full = log:date('%Y-%m-%d %H:%M:%S')

      assert.is_string(date_ymd)
      assert.is_string(date_full)
      assert.is_true(#date_full > #date_ymd)
    end)
  end)

  describe('age', function()
    it('should return age string from timestamp', function()
      local current_time = os.time()
      local one_hour_ago = current_time - 3600
      local line = string.format('Xabc1234\x1Fdef5678\x1F%d\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX', one_hour_ago)
      local log = GitLog(line)
      local age = log:age()

      assert.is_table(age)
      assert.is_string(age.display)
      assert.is_true(#age.display > 0)
    end)

    it('should handle recent timestamps', function()
      local current_time = os.time()
      local line = string.format('Xabc1234\x1Fdef5678\x1F%d\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX', current_time)
      local log = GitLog(line)
      local age = log:age()

      assert.is_table(age)
      assert.is_string(age.display)
    end)

    it('should handle old timestamps', function()
      local old_time = os.time() - (365 * 24 * 3600)
      local line = string.format('Xabc1234\x1Fdef5678\x1F%d\x1FJohn Doe\x1Fjohn@example.com\x1FCommitX', old_time)
      local log = GitLog(line)
      local age = log:age()

      assert.is_table(age)
      assert.is_string(age.display)
      assert.is_true(#age.display > 0)
    end)
  end)

  describe('edge cases', function()
    it('should handle empty summary', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FX'
      local log = GitLog(line)

      eq(log.summary, '')
    end)

    it('should handle author name with spaces', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Middle Doe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)

      eq(log.author_name, 'John Middle Doe')
    end)

    it('should handle very long summary', function()
      local long_summary = string.rep('a', 500)
      local line =
        string.format('Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1F%sX', long_summary)
      local log = GitLog(line)

      eq(log.summary, long_summary)
    end)

    it('should handle Unicode in author name', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Döe\x1Fjohn@example.com\x1FCommitX'
      local log = GitLog(line)

      eq(log.author_name, 'John Döe')
    end)

    it('should handle Unicode in summary', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FFix: 🐛 bugX'
      local log = GitLog(line)

      eq(log.summary, 'Fix: 🐛 bug')
    end)
  end)

  describe('data integrity', function()
    it('should preserve all fields with correct types', function()
      local line = 'Xabc1234\x1Fdef5678\x1F1234567890\x1FJohn Doe\x1Fjohn@example.com\x1FCommit messageX'
      local log = GitLog(line, 10)

      assert.is_string(log.id)
      assert.is_true(#log.id > 0, 'id should not be empty')

      assert.is_string(log.commit_hash)
      eq(log.commit_hash, 'abc1234')

      assert.is_string(log.parent_hash)
      eq(log.parent_hash, 'def5678')

      assert.is_string(log.timestamp)
      eq(log.timestamp, '1234567890')

      assert.is_string(log.author_name)
      eq(log.author_name, 'John Doe')

      assert.is_string(log.author_email)
      eq(log.author_email, 'john@example.com')

      assert.is_string(log.summary)
      eq(log.summary, 'Commit message')

      assert.is_string(log.revision)
      eq(log.revision, 'HEAD~10')
    end)
  end)
end)
