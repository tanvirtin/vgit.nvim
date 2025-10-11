local async = require('plenary.async.tests')
local git_log = require('vgit.git.git_log')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

local eq = assert.are.same

async.describe('git_log:', function()
  local repo

  async.before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['file1.txt'] = { 'initial content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  async.after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  async.describe('get()', function()
    async.it('should retrieve single commit by hash', function()
      local commit_hash = test_repo.get_head_commit(repo)

      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      assert(log)
      eq(log.commit_hash:sub(1, #commit_hash), commit_hash)
    end)

    async.it('should parse commit metadata correctly', function()
      -- Create a second commit so we have a commit with a parent
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'second commit' } },
        message = 'Second commit',
      })

      local commit_hash = test_repo.get_head_commit(repo)
      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      assert(log.commit_hash)
      assert(log.parent_hash) -- Now we have a parent since this is the second commit
      assert(log.timestamp)
      assert(log.author_name)
      assert(log.author_email)
      assert(log.summary)
    end)

    async.it('should retrieve commit by HEAD', function()
      local log, err = git_log.get(repo, 'HEAD')

      assert(not err)
      assert(log)
      assert(log.commit_hash)
    end)

    async.it('should retrieve commit by relative ref', function()
      -- Create second commit
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'second' } },
        message = 'Second commit',
      })

      local log, err = git_log.get(repo, 'HEAD~1')

      assert(not err)
      assert(log)
      eq(log.summary, 'Initial commit')
    end)

    async.it('should handle merge commits', function()
      -- Create a branch and merge
      test_repo.create_branch(repo, 'feature')
      test_repo.create_commit(repo, {
        files = { ['feature.txt'] = { 'feature' } },
        message = 'Feature commit',
      })

      test_repo.checkout(repo, 'master')
      test_repo.create_commit(repo, {
        files = { ['main.txt'] = { 'main' } },
        message = 'Main commit',
      })

      vim.fn.system({ 'git', '-C', repo, 'merge', 'feature', '--no-edit' })
      local merge_hash = test_repo.get_head_commit(repo)

      local log, err = git_log.get(repo, merge_hash)

      assert(not err)
      assert(log)
      -- Merge commit should have parent hash
      assert(log.parent_hash and #log.parent_hash > 0)
    end)

    async.it('should handle initial commit with no parent', function()
      local commit_hash = test_repo.get_head_commit(repo)

      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      -- Initial commit has no parent hash (should be nil)
      assert(log.parent_hash == nil)
    end)

    async.it('should parse author name with spaces', function()
      test_repo.create_commit(repo, {
        files = { ['file3.txt'] = { 'content' } },
        message = 'Test commit',
        author = 'John Middle Doe <john@example.com>',
      })

      local commit_hash = test_repo.get_head_commit(repo)
      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      eq(log.author_name, 'John Middle Doe')
    end)

    async.it('should parse author email correctly', function()
      test_repo.create_commit(repo, {
        files = { ['file4.txt'] = { 'content' } },
        message = 'Test commit',
        author = 'Test User <test+tag@example.com>',
      })

      local commit_hash = test_repo.get_head_commit(repo)
      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      eq(log.author_email, 'test+tag@example.com')
    end)

    async.it('should handle special characters in commit message', function()
      test_repo.create_commit(repo, {
        files = { ['file5.txt'] = { 'content' } },
        message = 'Fix: bug with "quotes" & symbols',
      })

      local commit_hash = test_repo.get_head_commit(repo)
      local log, err = git_log.get(repo, commit_hash)

      assert(not err)
      eq(log.summary, 'Fix: bug with "quotes" & symbols')
    end)

    async.it('should error on invalid commit hash', function()
      local log, err = git_log.get(repo, 'invalid_hash_123')

      assert(err)
      assert(not log)
    end)

    async.it('should error when reponame is missing', function()
      local log, err = git_log.get(nil, 'HEAD')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not log)
    end)

    async.it('should error when commit is missing', function()
      local log, err = git_log.get(repo, nil)

      assert(err)
      eq(err, { 'commit is required' })
      assert(not log)
    end)
  end)

  async.describe('list()', function()
    async.it('should list commits for repository', function()
      -- Create multiple commits
      for i = 2, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content ' .. i } },
          message = 'Commit ' .. i,
        })
      end

      local logs, err = git_log.list(repo)

      assert(not err)
      assert(logs)
      eq(#logs, 5) -- 1 initial + 4 new commits
    end)

    async.it('should parse all commit metadata', function()
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'content' } },
        message = 'Second commit',
      })

      local logs, err = git_log.list(repo)

      assert(not err)
      eq(#logs, 2)

      for i, log in ipairs(logs) do
        assert(log.commit_hash)
        -- First commit (logs[1]) has a parent, initial commit (logs[2]) does not
        if i == 1 then
          assert(log.parent_hash) -- Second commit has parent
        else
          assert(log.parent_hash == nil) -- Initial commit has no parent
        end
        assert(log.timestamp)
        assert(log.author_name)
        assert(log.author_email)
        assert(log.summary)
      end
    end)

    async.it('should respect pagination count', function()
      -- Create multiple commits
      for i = 2, 10 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content ' .. i } },
          message = 'Commit ' .. i,
        })
      end

      local logs, err = git_log.list(repo, {
        pagination = {
          count = 5,
          skip = 0,
        },
      })

      assert(not err)
      eq(#logs, 5)
    end)

    async.it('should respect pagination skip', function()
      -- Create multiple commits
      for i = 2, 10 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content ' .. i } },
          message = 'Commit ' .. i,
        })
      end

      local logs_first, err1 = git_log.list(repo, {
        pagination = {
          count = 5,
          skip = 0,
        },
      })

      local logs_second, err2 = git_log.list(repo, {
        pagination = {
          count = 5,
          skip = 5,
        },
      })

      assert(not err1)
      assert(not err2)
      eq(#logs_first, 5)
      eq(#logs_second, 5)

      -- First and second pages should have different commits
      assert(logs_first[1].commit_hash ~= logs_second[1].commit_hash)
    end)

    async.it('should filter by filename', function()
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'modified' } },
        message = 'Modify file1',
      })

      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'new file' } },
        message = 'Add file2',
      })

      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'modified again' } },
        message = 'Modify file1 again',
      })

      local logs, err = git_log.list(repo, {
        filename = 'file1.txt',
      })

      assert(not err)
      -- Should include initial + 2 modifications of file1.txt
      eq(#logs, 3)
    end)

    async.it('should handle empty repository', function()
      local empty_repo = test_repo.create_repo({ initial_commit = false })

      local logs, err = git_log.list(empty_repo)

      -- Empty repo should error (no commits exist)
      assert(err, 'Should error on empty repository')
      assert(not logs, 'Should not return logs')

      test_repo.cleanup(empty_repo)
    end)

    async.it('should return logs in reverse chronological order', function()
      local commits = {}
      for i = 2, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content ' .. i } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      local logs, err = git_log.list(repo)

      assert(not err)
      -- Most recent commit should be first
      eq(logs[1].commit_hash:sub(1, #commits[5]), commits[5])
    end)

    async.it('should handle very long history', function()
      -- Create many commits
      for i = 2, 50 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content ' .. i } },
          message = 'Commit ' .. i,
        })
      end

      local logs, err = git_log.list(repo)

      assert(not err)
      eq(#logs, 50)
    end)

    async.it('should work without pagination', function()
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'content' } },
        message = 'Second commit',
      })

      local logs, err = git_log.list(repo, {})

      assert(not err)
      eq(#logs, 2)
    end)

    async.it('should work with nil opts', function()
      local logs, err = git_log.list(repo, nil)

      assert(not err)
      assert(logs)
    end)

    async.it('should error when reponame is missing', function()
      local logs, err = git_log.list(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not logs)
    end)

    async.it('should handle commits with Unicode in author name', function()
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'content' } },
        message = 'Test commit',
        author = 'José García <jose@example.com>',
      })

      local logs, err = git_log.list(repo)

      assert(not err)
      assert(logs[1].author_name:match('José'))
    end)

    async.it('should handle commits with Unicode in message', function()
      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'content' } },
        message = 'Fix: 🐛 bug',
      })

      local logs, err = git_log.list(repo)

      assert(not err)
      assert(logs[1].summary:match('🐛'))
    end)

    async.it('should handle empty commit message', function()
      vim.fn.system({
        'git',
        '-C',
        repo,
        'commit',
        '--allow-empty',
        '--allow-empty-message',
        '-m',
        '',
      })

      local logs, err = git_log.list(repo)

      assert(not err)
      eq(logs[1].summary, '')
    end)

    async.it('should combine pagination and filename filter', function()
      -- Create commits for multiple files
      for i = 2, 10 do
        test_repo.create_commit(repo, {
          files = { ['file1.txt'] = { 'content ' .. i } },
          message = 'Modify file1 - ' .. i,
        })

        test_repo.create_commit(repo, {
          files = { ['file2.txt'] = { 'content ' .. i } },
          message = 'Modify file2 - ' .. i,
        })
      end

      local logs, err = git_log.list(repo, {
        filename = 'file1.txt',
        pagination = {
          count = 3,
          skip = 0,
        },
      })

      assert(not err)
      eq(#logs, 3)
    end)
  end)
end)
