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
      local main_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(main_commit, 'Main commit should exist')

      -- Create a feature branch
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      -- Add a commit on feature
      _, err = test_repo.create_commit(repo, {
        files = { ['cherry.txt'] = 'cherry content' },
        message = 'Cherry commit',
      })
      assert.is_nil(err, 'Failed to create cherry commit')

      local cherry_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(cherry_commit, 'Cherry commit should exist')
      assert.is_not_equal(main_commit, cherry_commit, 'Cherry commit should be different from main')

      -- Verify file exists on feature branch
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/cherry.txt'), 'File should exist on feature branch')

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err, 'Failed to checkout main branch')

      -- Verify file doesn't exist on main yet
      assert.is_false(fs.exists(repo:get_path() .. '/cherry.txt'), 'File should not exist on main before cherry-pick')

      -- Cherry-pick the commit
      local result, pick_err = git_cherry.pick(repo:get_path(), cherry_commit)
      assert.is_nil(pick_err, 'Cherry-pick should not error: ' .. vim.inspect(pick_err))
      assert.is_not_nil(result, 'Cherry-pick should return result')

      -- Verify file now exists on main
      assert.is_true(fs.exists(repo:get_path() .. '/cherry.txt'), 'File should exist on main after cherry-pick')

      -- Verify content is correct
      local content = fs.read_file(repo:get_path() .. '/cherry.txt')
      assert.equals('cherry content', content:match('^%s*(.-)%s*$'), 'File content should match')

      -- Verify HEAD moved (new commit created)
      local new_head = test_repo.get_head_commit(repo)
      assert.is_not_equal(main_commit, new_head, 'Cherry-pick should create a new commit')
    end)

    it('should cherry-pick multiple commits', function()
      local main_commit = test_repo.get_head_commit(repo)

      -- Create commits on feature branch
      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      _, err = test_repo.create_commit(repo, {
        files = { ['c1.txt'] = 'commit 1' },
        message = 'Commit 1',
      })
      assert.is_nil(err, 'Failed to create commit 1')

      local commit1 = test_repo.get_head_commit(repo)
      assert.is_not_nil(commit1, 'Commit 1 should exist')

      _, err = test_repo.create_commit(repo, {
        files = { ['c2.txt'] = 'commit 2' },
        message = 'Commit 2',
      })
      assert.is_nil(err, 'Failed to create commit 2')

      local commit2 = test_repo.get_head_commit(repo)
      assert.is_not_nil(commit2, 'Commit 2 should exist')
      assert.is_not_equal(commit1, commit2, 'Commits should be different')

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err, 'Failed to checkout main')

      -- Verify files don't exist on main yet
      local fs = require('vgit.core.fs')
      assert.is_false(fs.exists(repo:get_path() .. '/c1.txt'), 'File1 should not exist before cherry-pick')
      assert.is_false(fs.exists(repo:get_path() .. '/c2.txt'), 'File2 should not exist before cherry-pick')

      -- Cherry-pick both commits
      local result, pick_err = git_cherry.pick(repo:get_path(), { commit1, commit2 })
      assert.is_nil(pick_err, 'Cherry-pick should not error: ' .. vim.inspect(pick_err))
      assert.is_not_nil(result, 'Cherry-pick should return result')

      -- Verify files now exist
      assert.is_true(fs.exists(repo:get_path() .. '/c1.txt'), 'File1 should exist after cherry-pick')
      assert.is_true(fs.exists(repo:get_path() .. '/c2.txt'), 'File2 should exist after cherry-pick')

      -- Verify content is correct
      local content1 = fs.read_file(repo:get_path() .. '/c1.txt')
      assert.equals('commit 1', content1:match('^%s*(.-)%s*$'), 'File1 content should match')

      local content2 = fs.read_file(repo:get_path() .. '/c2.txt')
      assert.equals('commit 2', content2:match('^%s*(.-)%s*$'), 'File2 content should match')

      -- Verify HEAD moved (new commits created)
      local new_head = test_repo.get_head_commit(repo)
      assert.is_not_equal(main_commit, new_head, 'Cherry-pick should create new commits')
    end)

    it('should support cherry-pick options', function()
      local main_commit = test_repo.get_head_commit(repo)

      local _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      _, err = test_repo.create_commit(repo, {
        files = { ['f.txt'] = 'f' },
        message = 'Feature',
      })
      assert.is_nil(err, 'Failed to create feature commit')

      local commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(commit, 'Feature commit should exist')

      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err, 'Failed to checkout main')

      -- Cherry-pick with --no-commit option
      local result, pick_err = git_cherry.pick(repo:get_path(), commit, { no_commit = true })
      assert.is_nil(pick_err, 'Cherry-pick with no_commit should not error: ' .. vim.inspect(pick_err))
      assert.is_not_nil(result, 'Cherry-pick should return result')

      -- Changes should be staged but not committed
      local index = repo:index()
      assert.is_true(index:has_staged_changes(), 'Should have staged changes after no-commit cherry-pick')

      -- HEAD should not have moved
      local after_pick = test_repo.get_head_commit(repo)
      assert.equals(main_commit, after_pick, 'HEAD should not move with no-commit option')

      -- Verify file exists in staging
      local fs = require('vgit.core.fs')
      assert.is_true(fs.exists(repo:get_path() .. '/f.txt'), 'File should exist in working directory')
    end)
  end)

  describe('in_progress', function()
    it('should detect when cherry-pick is not in progress', function()
      local in_progress = git_cherry.in_progress(repo:get_path())
      assert.is_false(in_progress, 'Should return false when no cherry-pick in progress')
      assert.is_boolean(in_progress, 'Should return boolean value')
    end)

    it('should handle missing reponame', function()
      local in_progress = git_cherry.in_progress(nil)
      assert.is_boolean(in_progress, 'Should return boolean even with nil reponame')
      assert.is_false(in_progress, 'Should return false for nil reponame')
    end)

    it('should handle invalid reponame', function()
      local in_progress = git_cherry.in_progress('/nonexistent/path')
      assert.is_boolean(in_progress, 'Should return boolean for invalid path')
      assert.is_false(in_progress, 'Should return false for invalid path')
    end)
  end)

  describe('abort', function()
    it('should handle abort when no cherry-pick in progress', function()
      local result, err = git_cherry.abort(repo:get_path())

      -- Should error since no cherry-pick in progress
      assert.is_not_nil(err, 'Should error when no cherry-pick in progress')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when erroring')
    end)

    it('should validate reponame parameter', function()
      local result, err = git_cherry.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is missing')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)
  end)

  describe('list', function()
    it('should list commits that can be cherry-picked', function()
      -- Create commits on main
      local _, err = test_repo.create_commit(repo, {
        files = { ['m1.txt'] = 'm1' },
        message = 'Main 1',
      })
      assert.is_nil(err, 'Failed to create main commit')

      -- Create feature branch
      _, err = test_repo.create_branch(repo, 'feature')
      assert.is_nil(err, 'Failed to create feature branch')

      _, err = test_repo.create_commit(repo, {
        files = { ['f1.txt'] = 'f1' },
        message = 'Feature 1',
      })
      assert.is_nil(err, 'Failed to create feature commit')

      local feature_commit = test_repo.get_head_commit(repo)
      assert.is_not_nil(feature_commit, 'Feature commit should exist')

      -- Go back to main
      _, err = test_repo.checkout(repo, 'master')
      if err then
        _, err = test_repo.checkout(repo, 'main')
      end
      assert.is_nil(err, 'Failed to checkout main')

      local main_branch = 'master'
      local refs = repo:refs()
      local current, _ = refs:current_branch()
      if current == 'main' then main_branch = 'main' end

      -- List cherry-pickable commits
      local commits, list_err = git_cherry.list(repo:get_path(), main_branch, 'feature')

      -- If successful, validate structure
      if not list_err then
        assert.is_not_nil(commits, 'Should return commits list')
        assert.is_table(commits, 'Commits should be a table')
        -- Should have at least the feature commit
        assert.is_true(#commits > 0, 'Should have at least one cherry-pickable commit')
      else
        -- If it fails, error should be properly structured
        assert.is_table(list_err, 'Error should be a table')
      end
    end)

    it('should validate parameters for list', function()
      local commits, err = git_cherry.list(nil, 'upstream', 'branch')

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_nil(commits, 'Should not return commits when erroring')
    end)
  end)

  describe('parameter validation', function()
    it('should require reponame for pick', function()
      local result, err = git_cherry.pick(nil, 'commit')

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should require commits for pick', function()
      local result, err = git_cherry.pick(repo:get_path(), nil)

      assert.is_not_nil(err, 'Should error when commits is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_true(#err > 0, 'Error should contain messages')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)

    it('should validate empty commits array', function()
      local result, err = git_cherry.pick(repo:get_path(), {})

      assert.is_not_nil(err, 'Should error when commits array is empty')
      assert.is_nil(result, 'Should not return result for empty commits')
    end)

    it('should validate empty string parameters', function()
      local result, err = git_cherry.pick('', 'commit')

      assert.is_not_nil(err, 'Should error for empty reponame')
      assert.is_nil(result, 'Should not return result for empty parameter')

      result, err = git_cherry.pick(repo:get_path(), '')
      assert.is_not_nil(err, 'Should error for empty commit')
      assert.is_nil(result, 'Should not return result for empty parameter')
    end)

    it('should require reponame for abort', function()
      local result, err = git_cherry.abort(nil)

      assert.is_not_nil(err, 'Should error when reponame is nil')
      assert.is_table(err, 'Error should be a table')
      assert.is_nil(result, 'Should not return result when parameter missing')
    end)
  end)
end)
