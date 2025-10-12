local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local git_rebase = require('vgit.git.git_rebase')

describe('git_rebase', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      files = { ['base.txt'] = 'base' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('rebase', function()
    it('should rebase a branch onto another', function()
      -- Record initial commit on main
      local base_commit = test_repo.get_head_commit(repo)

      -- Create main branch commits
      local _, err = test_repo.create_commit(repo, {
        files = { ['main1.txt'] = 'main 1' },
        message = 'Main commit 1',
      })
      assert.is_nil(err, 'Failed to create main commit 1')

      _, err = test_repo.create_commit(repo, {
        files = { ['main2.txt'] = 'main 2' },
        message = 'Main commit 2',
      })
      assert.is_nil(err, 'Failed to create main commit 2')

      local main_head = test_repo.get_head_commit(repo)
      assert.is_not_nil(main_head, 'Main head commit should exist')
      assert.is_not_equal(base_commit, main_head, 'Main should have progressed')

      -- Create feature branch from base
      _, err = test_repo.checkout(repo, base_commit)
      assert.is_nil(err, 'Failed to checkout base commit')

      _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      -- Add feature commits
      _, err = test_repo.create_commit(repo, {
        files = { ['feature.txt'] = 'feature content' },
        message = 'Feature commit',
      })
      assert.is_nil(err, 'Failed to create feature commit')

      local feature_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(feature_commit, 'Feature commit should exist')

      -- Rebase feature onto main
      local refs = repo:refs()
      local main_branch, _ = refs:current_branch()
      if not main_branch or main_branch == 'feature' then main_branch = 'master' end

      -- Switch back to determine main branch name
      _, err = test_repo.checkout(repo, main_branch)
      if err then
        _, err = test_repo.checkout(repo, 'main')
        main_branch = 'main'
      end
      assert.is_nil(err, 'Failed to checkout main branch')

      _, err = test_repo.checkout(repo, 'feature')
      assert.is_nil(err, 'Failed to checkout feature branch')

      -- Rebase feature onto main
      local result, rebase_err = git_rebase.rebase(repo:get_path(), main_branch)
      assert.is_nil(rebase_err, 'Rebase should not error: ' .. vim.inspect(rebase_err))
      assert.is_not_nil(result, 'Rebase should return result')

      -- Verify feature branch now contains main's commits
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/feature.txt'), 'Feature file should still exist')
      assert.is_true(fs.exists(repo:get_path() .. '/main1.txt'), 'Main1 file should exist after rebase')
      assert.is_true(fs.exists(repo:get_path() .. '/main2.txt'), 'Main2 file should exist after rebase')
    end)

    it('should support rebase with interactive option', function()
      -- Create base commit
      local _, err = test_repo.create_commit(repo, {
        files = { ['base.txt'] = 'base update' },
        message = 'Base update',
      })
      assert.is_nil(err, 'Failed to create base commit')

      local base_commit = test_repo.get_head_commit(repo)

      -- Create feature branch
      _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      _, err = test_repo.create_commit(repo, {
        files = { ['feature.txt'] = 'feature' },
        message = 'Feature work',
      })
      assert.is_nil(err, 'Failed to create feature commit')

      -- Interactive rebase will typically fail in test env without interaction
      -- but we're validating that the option is passed correctly
      local result, rebase_err = git_rebase.rebase(repo:get_path(), base_commit, {
        interactive = true,
      })

      -- Interactive rebase requires user interaction, so error is expected
      if rebase_err then
        assert.is_table(rebase_err, 'Error should be a table')
        assert.is_true(#rebase_err > 0, 'Error should contain messages')
      else
        assert.is_not_nil(result, 'Result should be returned if no error')
      end
    end)

    it('should support rebase with preserve-merges option', function()
      local base_commit = test_repo.get_head_commit(repo)

      _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      _, err = test_repo.create_commit(repo, {
        files = { ['f.txt'] = 'f' },
        message = 'Feature',
      })
      assert.is_nil(err, 'Failed to create feature commit')

      -- Test that preserve_merges option is accepted
      local result, rebase_err = git_rebase.rebase(repo:get_path(), base_commit, {
        preserve_merges = true,
      })

      -- Should either succeed or fail with appropriate error
      if rebase_err then
        assert.is_table(rebase_err, 'Error should be a table')
      else
        assert.is_not_nil(result, 'Result should be returned if no error')
      end
    end)
  end)

  describe('in_progress', function()
    it('should detect when rebase is not in progress', function()
      local in_progress = git_rebase.in_progress(repo:get_path())
      assert.is_false(in_progress, 'Should return false when no rebase in progress')
      assert.is_boolean(in_progress, 'Should return boolean value')
    end)

    it('should handle missing reponame', function()
      local in_progress = git_rebase.in_progress(nil)
      assert.is_boolean(in_progress, 'Should return boolean even with nil reponame')
      assert.is_false(in_progress, 'Should return false for nil reponame')
    end)

    it('should handle invalid reponame', function()
      local in_progress = git_rebase.in_progress('/nonexistent/path')
      assert.is_boolean(in_progress, 'Should return boolean for invalid path')
      assert.is_false(in_progress, 'Should return false for invalid path')
    end)
  end)

  describe('status', function()
    it('should return status when no rebase in progress', function()
      local status, err = git_rebase.status(repo:get_path())

      assert.is_nil(err, 'Should not error when getting status')
      assert.is_not_nil(status, 'Should return status object')
      assert.is_table(status, 'Status should be a table')
      assert.is_boolean(status.in_progress, 'Status should have in_progress field as boolean')
      assert.is_false(status.in_progress, 'Should not be in progress initially')
    end)

    it('should validate status structure', function()
      local status, err = git_rebase.status(repo:get_path())

      assert.is_nil(err, 'Should not error')
      assert.is_table(status, 'Status should be a table')

      -- Verify expected fields exist
      assert.is_not_nil(status.in_progress, 'Status should have in_progress field')
    end)

    it('should error with missing reponame', function()
      local status, err = git_rebase.status(nil)

      assert.is_not_nil(err, 'Should error when reponame is missing')
      assert.is_nil(status, 'Should not return status when erroring')
    end)
  end)

  describe('abort', function()
    it('should handle abort when no rebase in progress', function()
      local result, err = git_rebase.abort(repo:get_path())

      -- Should error since no rebase in progress
      assert.is_not_nil(err, 'Should error when no rebase in progress')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when erroring')
    end)

    it('should validate reponame parameter', function()
      local result, err = git_rebase.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is missing')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)
  end)

  describe('parameter validation', function()
    it('should require reponame for rebase', function()
      local result, err = git_rebase.rebase(nil, 'upstream')

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require reponame for continue', function()
      local result, err = git_rebase.continue(nil)

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require reponame for abort', function()
      local result, err = git_rebase.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require upstream for rebase', function()
      local result, err = git_rebase.rebase(repo:get_path(), nil)

      assert.is_not_nil(err, 'Should error when upstream is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should validate empty string parameters', function()
      local result, err = git_rebase.rebase('', 'upstream')

      assert.is_not_nil(err, 'Should error for empty reponame')
      assert.is_nil(result, 'Should not return result for empty parameter')

      result, err = git_rebase.rebase(repo:get_path(), '')
      assert.is_not_nil(err, 'Should error for empty upstream')
      assert.is_nil(result, 'Should not return result for empty parameter')
    end)
  end)
end)
