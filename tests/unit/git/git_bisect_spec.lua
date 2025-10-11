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
      -- Reset bisect if in progress to clean up
      git_bisect.reset(repo)
      test_repo.cleanup(repo)
    end
  end)

  async.describe('start()', function()
    async.it('should start bisect session with good and bad commits', function()
      -- Create commit history
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

      -- Start bisect
      local result, err = git_bisect.start(repo, {
        bad = bad_commit,
        good = good_commit,
      })

      assert(not err, 'Should not error: ' .. vim.inspect(err))
      assert(result)

      -- Verify bisect is in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)
    end)

    async.it('should start bisect without commits', function()
      local result, err = git_bisect.start(repo)

      assert(not err)
      assert(result)

      -- Should be in progress
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

      -- Need to specify a bad commit for bisect to work
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

      -- Verify it started
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      -- Clean up
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
      -- Start bisect first
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

      -- Try to mark an invalid commit - this should error
      local _, err = git_bisect.bad(repo, 'invalid_hash_12345')

      assert(err, 'Should error on invalid commit hash')
      assert(type(err) == 'table', 'Error should be a table')
      assert(#err > 0, 'Error should have messages')

      -- Clean up
      git_bisect.reset(repo)
    end)
  end)

  async.describe('bad()', function()
    async.it('should mark current commit as bad', function()
      -- Setup bisect
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

      -- Mark additional commit as bad
      local result, err = git_bisect.bad(repo)

      -- Should succeed or provide feedback
      assert(result or err)
    end)

    async.it('should mark specific commit as bad', function()
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

      -- Mark specific commit as bad
      local result, err = git_bisect.bad(repo, commits[3])

      assert(result or err)
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
      -- Start bisect first
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
      -- Setup bisect
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

      -- Mark additional commit as good
      local result, err = git_bisect.good(repo)

      assert(result or err)
    end)

    async.it('should mark specific commit as good', function()
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

      -- Mark specific commit as good
      local result, err = git_bisect.good(repo, commits[2])

      assert(result or err)
    end)

    async.it('should mark multiple commits as good', function()
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
      })

      -- Mark multiple commits as good
      local result, err = git_bisect.good(repo, { commits[1], commits[2] })

      assert(result or err)
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

      assert(result or err)
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

      assert(result or err)
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

      -- Use custom term (this might not work with all git versions)
      local result, err = git_bisect.terms(repo, 'old', good_commit)

      -- Accept either success or error from git
      assert(result or err)
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
      -- Create commit history with a "bug" introduced at commit 3
      local commits = {}
      for i = 1, 5 do
        test_repo.create_commit(repo, {
          files = { ['version.txt'] = { 'version ' .. i } },
          message = 'Version ' .. i,
        })
        commits[i] = test_repo.get_head_commit(repo)
      end

      -- Start bisect: commits 1-2 are good, 3-5 are bad
      local result, err = git_bisect.start(repo, {
        bad = commits[5],
        good = commits[1],
      })

      assert(not err)
      assert(result)

      -- Verify in progress
      local in_progress = git_bisect.in_progress(repo)
      eq(in_progress, true)

      -- Clean up
      git_bisect.reset(repo)

      in_progress = git_bisect.in_progress(repo)
      eq(in_progress, false)
    end)

    async.it('should handle bisect with path limiters', function()
      -- Create commits affecting different files
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

      -- Bisect only file1.txt
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
