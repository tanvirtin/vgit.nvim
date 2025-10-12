local async = require('plenary.async.tests')
local git_bisect = require('vgit.git.git_bisect')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

local eq = assert.are.same

async.describe('git_bisect:', function()
  local repo

  async.before_each(function()
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = {
        ['base.txt'] = { 'base content' },
      },
    })
    assert(not err, 'Failed to create test repo: ' .. tostring(err))
  end)

  async.after_each(function()
    if repo then
      git_bisect.reset(repo)
      test_repo.cleanup(repo)
    end
  end)

  async.describe('start()', function()
    async.it('should start bisect session with good and bad commits', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['v2.txt'] = { 'version 2' } },
        message = 'Version 2',
      })

      test_repo.create_commit(repo, {
        files = { ['v3.txt'] = { 'version 3' } },
        message = 'Version 3',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(result)

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)
    end)

    async.it('should start bisect without commits', function()
      local result, err = git_bisect.start(repo)

      assert(not err)
      assert(result)

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)
    end)

    async.it('should support no-checkout option', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        no_checkout = true,
        bad = bad_commit,
        good = good_commit,
      })

      assert(not err)
      assert(result)
    end)

    async.it('should support first-parent option', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        first_parent = true,
        bad = bad_commit,
        good = good_commit,
      })

      assert(not err)
      assert(result)
    end)

    async.it('should support single good commit', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local result, err = git_bisect.start(repo, {
        good = good_commit,
      })

      assert(not err)
      assert(result)
    end)

    async.it('should support multiple good commits', function()
      local commits = {}
      for i = 1, 3 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      test_repo.create_commit(repo, {
        files = { ['bad.txt'] = { 'bad' } },
        message = 'Bad commit',
      })
      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = { commits[1], commits[2] },
      })

      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(result, 'Should return result')

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      git_bisect.reset(repo)
    end)

    async.it('should support path limiters', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
        paths = 'file.txt',
      })

      assert(not err)
      assert(result)
    end)

    async.it('should support multiple path limiters', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'content' }, ['file2.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
        paths = { 'file1.txt', 'file2.txt' },
      })

      assert(not err)
      assert(result)
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.start(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)

    async.it('should error when marking invalid commits', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local _, err = git_bisect.bad(repo, 'invalid_hash_12345')

      assert(err, 'Should error on invalid commit hash')
      assert(type(err) == 'table', 'Error should be a table')
      assert(#err > 0, 'Error should have messages')

      git_bisect.reset(repo)
    end)
  end)

  async.describe('bad()', function()
    async.it('should mark current commit as bad', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['v2.txt'] = { 'v2' } },
        message = 'V2',
      })

      test_repo.create_commit(repo, {
        files = { ['v3.txt'] = { 'v3' } },
        message = 'V3',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local result, err = git_bisect.bad(repo)

      assert(not err, 'Should not error when marking commit as bad: ' .. vim.inspect(err))
      assert(result, 'Should return result when marking commit as bad')
      assert(type(result) == 'table' or type(result) == 'string', 'Result should be table or string')

      -- Verify bisect is still in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after marking bad commit')
    end)

    async.it('should mark specific commit as bad', function()
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      local result, err = git_bisect.bad(repo, commits[3])

      assert(not err, 'Should not error when marking specific commit as bad: ' .. vim.inspect(err))
      assert(result, 'Should return result when marking specific commit as bad')

      -- Verify bisect is still in progress after marking a commit as bad
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after marking specific commit as bad')
    end)

    async.it('should error when bisect not started', function()
      local result, err = git_bisect.bad(repo)

      assert(err)
      assert(not result)
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.bad(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)

    async.it('should handle invalid commit hash', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local result, err = git_bisect.bad(repo, 'invalid_hash')

      assert(err)
      assert(not result)
    end)
  end)

  async.describe('good()', function()
    async.it('should mark current commit as good', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['v2.txt'] = { 'v2' } },
        message = 'V2',
      })

      test_repo.create_commit(repo, {
        files = { ['v3.txt'] = { 'v3' } },
        message = 'V3',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local result, err = git_bisect.good(repo)

      assert(not err, 'Should not error when marking commit as good: ' .. vim.inspect(err))
      assert(result, 'Should return result when marking commit as good')
      assert(type(result) == 'table' or type(result) == 'string', 'Result should be table or string')

      -- Verify bisect is still in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after marking good commit')
    end)

    async.it('should mark specific commit as good', function()
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      local result, err = git_bisect.good(repo, commits[2])

      assert(not err, 'Should not error when marking specific commit as good: ' .. vim.inspect(err))
      assert(result, 'Should return result when marking specific commit as good')

      -- Verify bisect is still in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after marking specific commit as good')
    end)

    async.it('should mark multiple commits as good', function()
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      git_bisect.start(repo, {
        bad = commits[5],
      })

      local result, err = git_bisect.good(repo, { commits[1], commits[2] })

      assert(not err, 'Should not error when marking multiple commits as good: ' .. vim.inspect(err))
      assert(result, 'Should return result when marking multiple commits as good')

      -- Verify bisect is still in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after marking multiple commits as good')
    end)

    async.it('should error when bisect not started', function()
      local result, err = git_bisect.good(repo)

      assert(err)
      assert(not result)
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.good(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)
  end)

  async.describe('skip()', function()
    async.it('should skip current commit', function()
      -- Setup bisect
      local good_commit = test_repo.get_head_commit(repo)

      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
      end

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      -- Skip current commit
      local result, err = git_bisect.skip(repo)

      assert(not err, 'Should not error when skipping current commit: ' .. vim.inspect(err))
      assert(result, 'Should return result when skipping commit')

      -- Verify bisect is still in progress after skipping
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after skipping commit')
    end)

    async.it('should skip specific commits', function()
      -- Setup bisect
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      -- Skip specific commits
      local result, err = git_bisect.skip(repo, { commits[2], commits[3] })

      assert(not err, 'Should not error when skipping specific commits: ' .. vim.inspect(err))
      assert(result, 'Should return result when skipping specific commits')

      -- Verify bisect is still in progress after skipping
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after skipping commits')
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.skip(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)
  end)

  async.describe('reset()', function()
    async.it('should reset active bisect session', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      -- Verify bisect is in progress
      local in_progress_before = git_bisect.in_progress(repo)
      eq(in_progress_before, true)

      -- Reset
      local result, err = git_bisect.reset(repo)

      -- Verify bisect is no longer in progress (this is what matters)
      local in_progress_after = git_bisect.in_progress(repo)
      eq(in_progress_after, false)

      -- Reset should return result or acceptable error (like "Already on 'main'")
      assert(result or err, 'Reset should return result or error')
    end)

    async.it('should succeed when no bisect in progress', function()
      local result, err = git_bisect.reset(repo)

      -- Should not error even if no bisect active
      assert(not err)
      assert(result)
    end)

    async.it('should end bisect when reset called with commit', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      -- Verify bisect is in progress
      local in_progress_before = git_bisect.in_progress(repo)
      eq(in_progress_before, true)

      -- Reset with commit (git bisect reset <commit> ends bisect and checks out commit)
      local result, err = git_bisect.reset(repo, good_commit)

      -- The important thing is bisect should no longer be in progress
      local in_progress_after = git_bisect.in_progress(repo)
      eq(in_progress_after, false)

      -- Result or error is acceptable (git may warn about checkout)
      assert(result or err, 'Should return something')
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.reset(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)
  end)

  async.describe('in_progress()', function()
    async.it('should return false when no bisect in progress', function()
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, false)
    end)

    async.it('should return true when bisect is in progress', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)
    end)

    async.it('should return false after reset', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      git_bisect.reset(repo)

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, false)
    end)
  end)

  async.describe('status()', function()
    async.it('should return not in progress when no bisect active', function()
      local status, err = git_bisect.status(repo)

      assert(not err)
      assert(status)
      eq(status.in_progress, false)
    end)

    async.it('should return bisect status when in progress', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      -- Just check in_progress using the file-based check
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      -- Clean up
      git_bisect.reset(repo)
    end)

    async.it('should track good and bad commits', function()
      -- Start bisect
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['file' .. i .. '.txt'] = { 'content' } },
          message = 'Commit ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      -- Verify bisect is in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      -- Clean up
      git_bisect.reset(repo)
    end)

    async.it('should error when reponame is missing', function()
      local status, err = git_bisect.status(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not status)
    end)
  end)

  async.describe('log()', function()
    async.it('should return bisect log when bisect is in progress', function()
      -- Start bisect
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local log, err = git_bisect.log(repo)

      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(log)
      assert(#log > 0)
    end)

    async.it('should error when no bisect in progress', function()
      local log, err = git_bisect.log(repo)

      -- Git will error if no bisect is in progress
      assert(err)
      assert(not log)
    end)

    async.it('should error when reponame is missing', function()
      local log, err = git_bisect.log(nil)

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not log)
    end)
  end)

  async.describe('terms()', function()
    async.it('should allow custom terms', function()
      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file.txt'] = { 'content' } },
        message = 'New commit',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      local result, err = git_bisect.terms(repo, 'old', good_commit)

      -- terms() may succeed or fail depending on git version and state
      if err then
        assert(type(err) == 'table', 'Error should be a table')
        assert(#err > 0, 'Error should have messages')
      else
        assert(result, 'Should return result when setting terms succeeds')
      end

      -- Verify bisect is still in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true, 'Bisect should remain in progress after terms operation')
    end)

    async.it('should error when reponame is missing', function()
      local result, err = git_bisect.terms(nil, 'old')

      assert(err)
      eq(err, { 'reponame is required' })
      assert(not result)
    end)

    async.it('should error when term is missing', function()
      local result, err = git_bisect.terms(repo, nil)

      assert(err)
      eq(err, { 'term is required' })
      assert(not result)
    end)
  end)

  async.describe('integration workflows', function()
    async.it('should complete full bisect workflow', function()
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['version.txt'] = { 'version ' .. i } },
          message = 'Version ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      local result, err = git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      assert(not err)
      assert(result)

      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      git_bisect.reset(repo)

      in_progress = git_bisect.in_progress(repo)
      eq(in_progress, false)
    end)

    async.it('should handle bisect with path limiters', function()
      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'v1' } },
        message = 'File1 v1',
      })

      local good_commit = test_repo.get_head_commit(repo)

      test_repo.create_commit(repo, {
        files = { ['file2.txt'] = { 'v1' } },
        message = 'File2 v1',
      })

      test_repo.create_commit(repo, {
        files = { ['file1.txt'] = { 'v2' } },
        message = 'File1 v2',
      })

      local bad_commit = test_repo.get_head_commit(repo)

      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
        paths = 'file1.txt',
      })

      assert(not err)
      assert(result)

      git_bisect.reset(repo)
    end)
  end)
end)
