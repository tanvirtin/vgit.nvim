local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local git_revert = require('vgit.git.git_revert')

describe('git_revert', function()
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

  describe('revert', function()
    it('should revert a commit', function()
      -- Get initial state
      local initial_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(initial_commit, 'Initial commit should exist')

      -- Create a commit to revert
      local _, err = test_repo.create_commit(repo, {
        files = { ['unwanted.txt'] = 'unwanted content' },
        message = 'Unwanted commit',
      })
      assert.is_nil(err, 'Failed to create commit to revert')

      local unwanted_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(unwanted_commit, 'Unwanted commit should exist')
      assert.is_not_equal(initial_commit, unwanted_commit, 'New commit should be different from initial')

      -- Verify file exists before revert
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/unwanted.txt'), 'File should exist before revert')

      -- Revert the commit
      local result, revert_err = git_revert.revert(repo:get_path(), unwanted_commit)
      assert.is_nil(revert_err, 'Revert should not error: ' .. vim.inspect(revert_err))
      assert.is_not_nil(result, 'Revert should return result')

      -- File should be gone after revert
      assert.is_false(fs.exists(repo:get_path() .. '/unwanted.txt'), 'File should not exist after revert')

      -- Verify a new commit was created for the revert
      local final_commit = test_repo.get_head_commit(repo)
      assert.is_not_equal(unwanted_commit, final_commit, 'Revert should create a new commit')
      assert.is_not_equal(initial_commit, final_commit, 'Final commit should be different from initial')
    end)

    it('should revert multiple commits', function()
      local initial_commit = test_repo.get_head_commit(repo)

      -- Create commits
      local _, err = test_repo.create_commit(repo, {
        files = { ['file1.txt'] = 'content 1' },
        message = 'Commit 1',
      })
      assert.is_nil(err, 'Failed to create commit 1')

      local commit1 = test_repo.get_head_commit(repo)
      assert.is_not_nil(commit1, 'Commit 1 should exist')

      _, err = test_repo.create_commit(repo, {
        files = { ['file2.txt'] = 'content 2' },
        message = 'Commit 2',
      })
      assert.is_nil(err, 'Failed to create commit 2')

      local commit2 = test_repo.get_head_commit(repo)
      assert.is_not_nil(commit2, 'Commit 2 should exist')
      assert.is_not_equal(commit1, commit2, 'Commits should be different')

      -- Create a newer commit on top
      _, err = test_repo.create_commit(repo, {
        files = { ['keep.txt'] = 'keep this' },
        message = 'Keep this',
      })
      assert.is_nil(err, 'Failed to create keep commit')

      local before_revert = test_repo.get_head_commit(repo)

      -- Verify files exist before revert
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/file1.txt'), 'File1 should exist before revert')
      assert.is_true(fs.exists(repo:get_path() .. '/file2.txt'), 'File2 should exist before revert')
      assert.is_true(fs.exists(repo:get_path() .. '/keep.txt'), 'Keep file should exist before revert')

      -- Revert both commits in reverse order
      local result, revert_err = git_revert.revert(repo:get_path(), { commit2, commit1 })
      assert.is_nil(revert_err, 'Revert should not error: ' .. vim.inspect(revert_err))
      assert.is_not_nil(result, 'Revert should return result')

      -- Files should be gone
      assert.is_false(fs.exists(repo:get_path() .. '/file1.txt'), 'File1 should not exist after revert')
      assert.is_false(fs.exists(repo:get_path() .. '/file2.txt'), 'File2 should not exist after revert')
      -- Keep file should still exist
      assert.is_true(fs.exists(repo:get_path() .. '/keep.txt'), 'Keep file should still exist after revert')

      -- Verify new commits were created for the reverts
      local after_revert = test_repo.get_head_commit(repo)
      assert.is_not_equal(before_revert, after_revert, 'Revert should create new commits')
    end)

    it('should support revert options', function()
      local before_commit = test_repo.get_head_commit(repo)

      local _, err = test_repo.create_commit(repo, {
        files = { ['file.txt'] = 'content' },
        message = 'Commit',
      })
      assert.is_nil(err, 'Failed to create commit')

      local commit = test_repo.get_head_commit(repo)
      assert.is_not_equal(before_commit, commit, 'New commit should be created')

      -- Revert with --no-commit
      local result, revert_err = git_revert.revert(repo:get_path(), commit, { no_commit = true })
      assert.is_nil(revert_err, 'Revert with no_commit should not error: ' .. vim.inspect(revert_err))
      assert.is_not_nil(result, 'Revert should return result')

      -- Changes should be staged but not committed
      local index = repo:index()
      assert.is_true(index:has_staged_changes(), 'Should have staged changes after no-commit revert')

      -- HEAD should not have moved
      local after_revert = test_repo.get_head_commit(repo)
      assert.equals(commit, after_revert, 'HEAD should not move with no-commit option')
    end)
  end)

  describe('in_progress', function()
    it('should detect when revert is not in progress', function()
      local in_progress = git_revert.in_progress(repo:get_path())
      assert.is_false(in_progress, 'Should return false when no revert in progress')
      assert.is_boolean(in_progress, 'Should return boolean value')
    end)

    it('should handle missing reponame', function()
      local in_progress = git_revert.in_progress(nil)
      assert.is_boolean(in_progress, 'Should return boolean even with nil reponame')
      assert.is_false(in_progress, 'Should return false for nil reponame')
    end)

    it('should handle invalid reponame', function()
      local in_progress = git_revert.in_progress('/nonexistent/path')
      assert.is_boolean(in_progress, 'Should return boolean for invalid path')
      assert.is_false(in_progress, 'Should return false for invalid path')
    end)
  end)

  describe('abort', function()
    it('should handle abort when no revert in progress', function()
      local result, err = git_revert.abort(repo:get_path())

      -- Should error since no revert in progress
      assert.is_not_nil(err, 'Should error when no revert in progress')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when erroring')
    end)

    it('should validate reponame parameter', function()
      local result, err = git_revert.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is missing')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)
  end)

  describe('parameter validation', function()
    it('should require reponame for revert', function()
      local result, err = git_revert.revert(nil, 'commit')

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require reponame for continue', function()
      local result, err = git_revert.continue(nil)

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require reponame for abort', function()
      local result, err = git_revert.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require commits for revert', function()
      local result, err = git_revert.revert(repo:get_path(), nil)

      assert.is_not_nil(err, 'Should error when commits is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should validate empty commits array', function()
      local result, err = git_revert.revert(repo:get_path(), {})

      assert.is_not_nil(err, 'Should error when commits array is empty')
      assert.is_nil(result, 'Should not return result for empty commits')
    end)

    it('should validate empty string parameters', function()
      local result, err = git_revert.revert('', 'commit')

      assert.is_not_nil(err, 'Should error for empty reponame')
      assert.is_nil(result, 'Should not return result for empty parameter')

      result, err = git_revert.revert(repo:get_path(), '')
      assert.is_not_nil(err, 'Should error for empty commit')
      assert.is_nil(result, 'Should not return result for empty parameter')
    end)
  end)
end)
