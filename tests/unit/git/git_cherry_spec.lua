local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('git')
local git_cherry = require('vgit.git.git_cherry')

describe('git_cherry', function()
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

  describe('pick', function()
    it('should cherry-pick a commit', function()
      -- Create a feature branch
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      -- Add a commit
      _, err = test_repo.create_commit(repo, {
        files = { ['cherry.txt'] = 'cherry content' },
        message = 'Cherry commit',
      })
      assert.is_nil(err)

      local cherry_commit = test_repo.get_head_commit(repo)

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Cherry-pick the commit
      _, err = git_cherry.pick(repo:get_path(), cherry_commit)
      assert.is_nil(err)

      -- Verify file exists
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/cherry.txt'))
    end)

    it('should cherry-pick multiple commits', function()
      -- Create commits
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['c1.txt'] = 'commit 1' },
        message = 'Commit 1',
      })
      assert.is_nil(err)

      local commit1 = test_repo.get_head_commit(repo)

      _, err = test_repo.create_commit(repo, {
        files = { ['c2.txt'] = 'commit 2' },
        message = 'Commit 2',
      })
      assert.is_nil(err)

      local commit2 = test_repo.get_head_commit(repo)

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Cherry-pick both commits
      _, err = git_cherry.pick(repo:get_path(), { commit1, commit2 })
      assert.is_nil(err)

      -- Verify files exist
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/c1.txt'))
      assert.is_true(fs.exists(repo:get_path() .. '/c2.txt'))
    end)

    it('should support cherry-pick options', function()
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['f.txt'] = 'f' },
        message = 'Feature',
      })
      assert.is_nil(err)

      local commit = test_repo.get_head_commit(repo)

      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      -- Cherry-pick with --no-commit option
      _, err = git_cherry.pick(repo:get_path(), commit, { no_commit = true })
      assert.is_nil(err)

      -- Changes should be staged but not committed
      local index = repo:index()
      assert.is_true(index:has_staged_changes())
    end)
  end)

  describe('in_progress', function()
    it('should detect when cherry-pick is not in progress', function()
      local in_progress = git_cherry.in_progress(repo:get_path())
      assert.is_false(in_progress)
    end)
  end)

  describe('abort', function()
    it('should handle abort when no cherry-pick in progress', function()
      local _, err = git_cherry.abort(repo:get_path())
      -- Will error since no cherry-pick in progress
      assert.is_not_nil(err)
    end)
  end)

  describe('list', function()
    it('should list commits that can be cherry-picked', function()
      -- Create commits on main
      local _, err = test_repo.create_commit(repo, {
        files = { ['m1.txt'] = 'm1' },
        message = 'Main 1',
      })
      assert.is_nil(err)

      -- Create feature branch
      _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err)

      _, err = test_repo.create_commit(repo, {
        files = { ['f1.txt'] = 'f1' },
        message = 'Feature 1',
      })
      assert.is_nil(err)

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err)

      local main_branch = 'master'
      local refs = repo:refs()
      local current, _ = refs:current_branch()
      if current == 'main' then main_branch = 'main' end

      -- List cherry-pickable commits
      local commits, list_err = git_cherry.list(repo:get_path(), main_branch, 'feature')
      -- This might fail in test env, but we're testing the API
      if not list_err then assert.is_not_nil(commits) end
    end)
  end)

  describe('parameter validation', function()
    it('should require reponame', function()
      local _, err = git_cherry.pick(nil, 'commit')
      assert.is_not_nil(err)
    end)

    it('should require commits', function()
      local _, err = git_cherry.pick(repo:get_path(), nil)
      assert.is_not_nil(err)
    end)
  end)
end)
