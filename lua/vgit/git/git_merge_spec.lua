local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
local git_merge = require('vgit.git.git_merge')
local it = async.it
local before_each = async.before_each
local after_each = async.after_each

describe('git_merge', function()
  local repo

  before_each(function()
    local err
    repo, err = test_repo.create_repo({
      files = { ['base.txt'] = 'base content' },
      initial_commit = true,
    })
    assert.is_nil(err)
    assert.is_not_nil(repo)
  end)

  after_each(function()
    if repo then test_repo.cleanup(repo) end
  end)

  describe('merge', function()
    it('should merge a branch with fast-forward', function()
      -- Create feature branch
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      -- Add commit to feature
      _, err = test_repo.create_commit(repo, {
        files = { ['feature.txt'] = 'feature content' },
        message = 'Add feature',
      })
      assert.is_nil(err)

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Merge feature (should fast-forward)
      _, err = git_merge.merge(repo:get_path(), 'feature')
      assert.is_nil(err)

      -- Verify file exists
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/feature.txt'))
    end)

    it('should merge with --no-ff option', function()
      -- Create and merge feature branch
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['feature.txt'] = 'feature' },
        message = 'Feature',
      })
      assert.is_nil(err)

      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Merge with no-ff
      _, err = git_merge.merge(repo:get_path(), 'feature', {
        no_ff = true,
        message = 'Merge feature branch',
      })
      assert.is_nil(err)
    end)

    it('should merge with --squash option', function()
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['f1.txt'] = 'f1' },
        message = 'Commit 1',
      })
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['f2.txt'] = 'f2' },
        message = 'Commit 2',
      })
      assert.is_nil(err)

      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Squash merge
      _, err = git_merge.merge(repo:get_path(), 'feature', { squash = true })
      assert.is_nil(err)

      -- Need to commit the squashed changes
      local index = repo:index()
      _, err = index:commit('Squashed feature')
      assert.is_nil(err)
    end)

    it('should return error for missing parameters', function()
      local _, err = git_merge.merge(nil, 'branch')
      assert.is_not_nil(err)

      _, err = git_merge.merge(repo:get_path(), nil)
      assert.is_not_nil(err)
    end)
  end)

  describe('merge with conflicts', function()
    before_each(function()
      -- Create conflict scenario
      local _, err = test_repo.create_conflict(repo)
      assert.is_nil(err)
    end)

    it('should detect merge in progress', function()
      local in_progress = git_merge.in_progress(repo:get_path())
      assert.is_true(in_progress)
    end)

    it('should abort merge', function()
      local _, err = git_merge.abort(repo:get_path())
      assert.is_nil(err)

      -- Verify merge is no longer in progress
      local in_progress = git_merge.in_progress(repo:get_path())
      assert.is_false(in_progress)
    end)

    it('should quit merge', function()
      local _, err = git_merge.quit(repo:get_path())
      assert.is_nil(err)
    end)
  end)

  describe('merge_base', function()
    it('should find merge base between commits', function()
      -- Create two diverging branches
      local commit1 = test_repo.get_head_commit(repo)

      -- Create branch A
      local _, err = test_repo.create_branch(repo, 'branch-a')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['a.txt'] = 'a' },
        message = 'Commit A',
      })
      assert.is_nil(err)

      local commit_a = test_repo.get_head_commit(repo)

      -- Create branch B from base
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      _, err = test_repo.create_branch(repo, 'branch-b')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['b.txt'] = 'b' },
        message = 'Commit B',
      })
      assert.is_nil(err)

      local commit_b = test_repo.get_head_commit(repo)

      -- Find merge base
      local base, base_err = git_merge.base(repo:get_path(), commit_a, commit_b)
      assert.is_nil(base_err)
      assert.is_not_nil(base)
      assert.equals(commit1, base)
    end)
  end)

  describe('is_ancestor', function()
    it('should check if commit is ancestor', function()
      local commit1 = test_repo.get_head_commit(repo)

      -- Create another commit
      local _, err = test_repo.create_commit(repo, {
        files = { ['new.txt'] = 'new' },
        message = 'New commit',
      })
      assert.is_nil(err)

      local commit2 = test_repo.get_head_commit(repo)

      -- Check ancestry
      local is_ancestor = git_merge.is_ancestor(repo:get_path(), commit1, commit2)
      assert.is_true(is_ancestor)

      -- Reverse should be false
      is_ancestor = git_merge.is_ancestor(repo:get_path(), commit2, commit1)
      assert.is_false(is_ancestor)
    end)
  end)
end)
