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
      -- Create a commit to revert
      local _, err = test_repo.create_commit(repo, {
        files = { ['unwanted.txt'] = 'unwanted content' },
        message = 'Unwanted commit',
      })
      assert.is_nil(err)

      local unwanted_commit = test_repo.get_head_commit(repo)

      -- Verify file exists
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/unwanted.txt'))

      -- Revert the commit
      _, err = git_revert.revert(repo:get_path(), unwanted_commit)
      assert.is_nil(err)

      -- File should be gone after revert
      assert.is_false(fs.exists(repo:get_path() .. '/unwanted.txt'))
    end)

    it('should revert multiple commits', function()
      -- Create commits
      local _, err = test_repo.create_commit(repo, {
        files = { ['file1.txt'] = 'content 1' },
        message = 'Commit 1',
      })
      assert.is_nil(err)

      local commit1 = test_repo.get_head_commit(repo)

      _, err = test_repo.create_commit(repo, {
        files = { ['file2.txt'] = 'content 2' },
        message = 'Commit 2',
      })
      assert.is_nil(err)

      local commit2 = test_repo.get_head_commit(repo)

      -- Create a newer commit on top
      _, err = test_repo.create_commit(repo, {
        files = { ['keep.txt'] = 'keep this' },
        message = 'Keep this',
      })
      assert.is_nil(err)

      -- Revert both commits in reverse order
      _, err = git_revert.revert(repo:get_path(), { commit2, commit1 })
      assert.is_nil(err)

      -- Files should be gone
      local fs = require('vgit.core.fs')
      assert.is_false(fs.exists(repo:get_path() .. '/file1.txt'))
      assert.is_false(fs.exists(repo:get_path() .. '/file2.txt'))
      -- Keep file should still exist
      assert.is_true(fs.exists(repo:get_path() .. '/keep.txt'))
    end)

    it('should support revert options', function()
      local _, err = test_repo.create_commit(repo, {
        files = { ['file.txt'] = 'content' },
        message = 'Commit',
      })
      assert.is_nil(err)

      local commit = test_repo.get_head_commit(repo)

      -- Revert with --no-commit
      _, err = git_revert.revert(repo:get_path(), commit, { no_commit = true })
      assert.is_nil(err)

      -- Changes should be staged but not committed
      local index = repo:index()
      assert.is_true(index:has_staged_changes())
    end)
  end)

  describe('in_progress', function()
    it('should detect when revert is not in progress', function()
      local in_progress = git_revert.in_progress(repo:get_path())
      assert.is_false(in_progress)
    end)
  end)

  describe('abort', function()
    it('should handle abort when no revert in progress', function()
      local _, err = git_revert.abort(repo:get_path())
      -- Will error since no revert in progress
      assert.is_not_nil(err)
    end)
  end)

  describe('parameter validation', function()
    it('should require reponame', function()
      local _, err = git_revert.revert(nil, 'commit')
      assert.is_not_nil(err)

      _, err = git_revert.continue(nil)
      assert.is_not_nil(err)

      _, err = git_revert.abort(nil)
      assert.is_not_nil(err)
    end)

    it('should require commits', function()
      local _, err = git_revert.revert(repo:get_path(), nil)
      assert.is_not_nil(err)
    end)
  end)
end)
