local GitIndex = require('vgit.git.GitIndex')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

local function make_repo(path)
  return {
    get_path = function()
      return path or '/repo'
    end,
  }
end

describe('GitIndex:', function()
  -- =========================================================================
  -- Unit tests (no repo needed, synchronous)
  -- =========================================================================
  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitIndex(nil)
      end, 'GitIndex requires a repository')
    end)

    it('should create instance with valid repository', function()
      local index = GitIndex(make_repo('/my/repo'))

      eq('/my/repo', index._repo_path)
      assert.is_nil(index._staged_files)
    end)
  end)

  describe('add_hunk', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:add_hunk(nil, { type = 'add' })

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)

    it('should return error when hunk is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:add_hunk('file.txt', nil)

      assert.is_nil(result)
      eq({ 'hunk is required' }, err)
    end)
  end)

  describe('remove_hunk', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:remove_hunk(nil, { type = 'add' })

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)

    it('should return error when hunk is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:remove_hunk('file.txt', nil)

      assert.is_nil(result)
      eq({ 'hunk is required' }, err)
    end)
  end)

  describe('file_status', function()
    it('should return error when filename is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:file_status(nil)

      assert.is_nil(result)
      eq({ 'filename is required' }, err)
    end)
  end)

  describe('commit', function()
    it('should return error when message is nil', function()
      local index = GitIndex(make_repo())
      local result, err = index:commit(nil)

      assert.is_nil(result)
      eq({ 'commit message is required' }, err)
    end)

    it('should return error when message is empty string', function()
      local index = GitIndex(make_repo())
      local result, err = index:commit('')

      assert.is_nil(result)
      eq({ 'commit message is required' }, err)
    end)
  end)

  describe('reset_cache', function()
    it('should clear _staged_files', function()
      local index = GitIndex(make_repo())
      index._staged_files = { 'cached' }

      index:reset_cache()
      assert.is_nil(index._staged_files)
    end)
  end)

  -- =========================================================================
  -- Integration tests (real repo, async)
  -- =========================================================================
  describe('integration', function()
    local repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = {
          ['file1.txt'] = { 'line one', 'line two', 'line three' },
          ['file2.txt'] = { 'alpha', 'beta' },
        },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
    end)

    -- -----------------------------------------------------------------------
    -- is_clean
    -- -----------------------------------------------------------------------
    describe('is_clean', function()
      it('should return true for a fresh repo after commit', function()
        local index = GitIndex(make_repo(repo))
        local result, err = index:is_clean()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should return false when there are modifications', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:is_clean()

        assert.is_nil(err)
        eq(false, result)
      end)

      it('should return false when there are untracked files', function()
        test_repo.write_file(repo, 'untracked.txt', { 'new file' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:is_clean()

        assert.is_nil(err)
        eq(false, result)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- status
    -- -----------------------------------------------------------------------
    describe('status', function()
      it('should return empty list for clean repo', function()
        local index = GitIndex(make_repo(repo))
        local files, err = index:status()

        assert.is_nil(err)
        eq(0, #files)
      end)

      it('should return entries when files are modified', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed content' })

        local index = GitIndex(make_repo(repo))
        local files, err = index:status()

        assert.is_nil(err)
        assert.is_true(#files > 0)
      end)

      it('should include untracked files', function()
        test_repo.write_file(repo, 'brand_new.txt', { 'hello' })

        local index = GitIndex(make_repo(repo))
        local files, err = index:status()

        assert.is_nil(err)
        eq(1, #files)
        eq('brand_new.txt', files[1].filename)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- file_status
    -- -----------------------------------------------------------------------
    describe('file_status', function()
      it('should return status for a specific modified file', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })

        local index = GitIndex(make_repo(repo))
        local file_info, err = index:file_status('file1.txt')

        assert.is_nil(err)
        assert.is_not_nil(file_info)
        eq('file1.txt', file_info.filename)
      end)

      it('should return nil for a file with no changes', function()
        local index = GitIndex(make_repo(repo))
        local file_info, err = index:file_status('file1.txt')

        assert.is_nil(err)
        assert.is_nil(file_info)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- add
    -- -----------------------------------------------------------------------
    describe('add', function()
      it('should stage a modified file', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified content' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:add('file1.txt')

        assert.is_nil(err)
        eq(true, result)

        local has, has_err = index:has_staged_changes()
        assert.is_nil(has_err)
        eq(true, has)
      end)

      it('should invalidate staged_files cache on success', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified content' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        -- populate cache
        local staged, _ = index:staged_files()
        assert.is_not_nil(staged)
        assert.is_not_nil(index._staged_files)

        -- modify another file and add it
        test_repo.modify_file(repo, 'file2.txt', { 'also modified' })
        index:add('file2.txt')

        -- cache should be invalidated
        assert.is_nil(index._staged_files)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- add_all
    -- -----------------------------------------------------------------------
    describe('add_all', function()
      it('should stage all modified files', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed one' })
        test_repo.modify_file(repo, 'file2.txt', { 'changed two' })
        test_repo.write_file(repo, 'new_file.txt', { 'brand new' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:add_all()

        assert.is_nil(err)
        eq(true, result)

        local staged, staged_err = index:staged_files()
        assert.is_nil(staged_err)
        eq(3, #staged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- staged_files / unstaged_files
    -- -----------------------------------------------------------------------
    describe('staged_files', function()
      it('should return only staged files', function()
        test_repo.modify_file(repo, 'file1.txt', { 'staged change' })
        test_repo.modify_file(repo, 'file2.txt', { 'unstaged change' })
        -- Stage only file1
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local staged, err = index:staged_files()

        assert.is_nil(err)
        eq(1, #staged)
        eq('file1.txt', staged[1].filename)
        assert.is_true(staged[1]:is_staged())
      end)

      it('should return empty table when nothing is staged', function()
        test_repo.modify_file(repo, 'file1.txt', { 'unstaged only' })

        local index = GitIndex(make_repo(repo))
        local staged, err = index:staged_files()

        assert.is_nil(err)
        eq(0, #staged)
      end)

      it('should cache results on subsequent calls', function()
        test_repo.modify_file(repo, 'file1.txt', { 'staged change' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))

        local staged1, err1 = index:staged_files()
        assert.is_nil(err1)
        eq(1, #staged1)

        -- Second call should use cache (same object reference)
        local staged2, err2 = index:staged_files()
        assert.is_nil(err2)
        assert.is_true(rawequal(staged1, staged2))
      end)
    end)

    describe('unstaged_files', function()
      it('should return only unstaged files', function()
        test_repo.modify_file(repo, 'file1.txt', { 'staged change' })
        test_repo.modify_file(repo, 'file2.txt', { 'unstaged change' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local unstaged, err = index:unstaged_files()

        assert.is_nil(err)
        eq(1, #unstaged)
        eq('file2.txt', unstaged[1].filename)
        assert.is_true(unstaged[1]:is_unstaged())
      end)

      it('should include untracked files', function()
        test_repo.write_file(repo, 'untracked.txt', { 'new' })

        local index = GitIndex(make_repo(repo))
        local unstaged, err = index:unstaged_files()

        assert.is_nil(err)
        eq(1, #unstaged)
        eq('untracked.txt', unstaged[1].filename)
      end)

      it('should return empty table when all changes are staged', function()
        test_repo.modify_file(repo, 'file1.txt', { 'staged' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local unstaged, err = index:unstaged_files()

        assert.is_nil(err)
        eq(0, #unstaged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- has_staged_changes / has_unstaged_changes
    -- -----------------------------------------------------------------------
    describe('has_staged_changes', function()
      it('should return true when staged files exist', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:has_staged_changes()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should return false when no staged files', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified but not staged' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:has_staged_changes()

        assert.is_nil(err)
        eq(false, result)
      end)

      it('should return false for a clean repo', function()
        local index = GitIndex(make_repo(repo))
        local result, err = index:has_staged_changes()

        assert.is_nil(err)
        eq(false, result)
      end)
    end)

    describe('has_unstaged_changes', function()
      it('should return true when unstaged files exist', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:has_unstaged_changes()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should return false when all changes are staged', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:has_unstaged_changes()

        assert.is_nil(err)
        eq(false, result)
      end)

      it('should return false for a clean repo', function()
        local index = GitIndex(make_repo(repo))
        local result, err = index:has_unstaged_changes()

        assert.is_nil(err)
        eq(false, result)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- remove
    -- -----------------------------------------------------------------------
    describe('remove', function()
      it('should unstage a staged file', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))

        -- Confirm it is staged
        local has_before, _ = index:has_staged_changes()
        eq(true, has_before)

        -- Remove (unstage) it
        local result, err = index:remove('file1.txt')
        assert.is_nil(err)
        eq(true, result)

        -- Reset cache so staged_files refetches
        index:reset_cache()
        local has_after, has_err = index:has_staged_changes()
        assert.is_nil(has_err)
        eq(false, has_after)

        -- But unstaged changes should still exist
        local has_unstaged, unstaged_err = index:has_unstaged_changes()
        assert.is_nil(unstaged_err)
        eq(true, has_unstaged)
      end)

      it('should invalidate staged_files cache on success', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        -- Populate cache
        index:staged_files()
        assert.is_not_nil(index._staged_files)

        -- Remove
        index:remove('file1.txt')
        assert.is_nil(index._staged_files)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- reset
    -- -----------------------------------------------------------------------
    describe('reset', function()
      it('should unstage all staged files', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed one' })
        test_repo.modify_file(repo, 'file2.txt', { 'changed two' })
        test_repo.stage(repo, { 'file1.txt', 'file2.txt' })

        local index = GitIndex(make_repo(repo))

        -- Confirm both are staged
        local staged_before, _ = index:staged_files()
        eq(2, #staged_before)

        -- Reset
        local result, err = index:reset()
        assert.is_nil(err)
        eq(true, result)

        -- After reset, nothing should be staged
        index:reset_cache()
        local staged_after, staged_err = index:staged_files()
        assert.is_nil(staged_err)
        eq(0, #staged_after)

        -- But unstaged changes should still exist
        local unstaged, unstaged_err = index:unstaged_files()
        assert.is_nil(unstaged_err)
        eq(2, #unstaged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- commit
    -- -----------------------------------------------------------------------
    describe('commit', function()
      it('should commit staged changes and leave repo clean', function()
        test_repo.modify_file(repo, 'file1.txt', { 'committed change' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:commit('test commit message')

        assert.is_nil(err)
        eq(true, result)

        -- After commit, repo should be clean
        local clean, clean_err = index:is_clean()
        assert.is_nil(clean_err)
        eq(true, clean)
      end)

      it('should return error when no staged changes exist', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified but not staged' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:commit('test commit')

        assert.is_nil(result)
        eq({ 'no staged changes to commit' }, err)
      end)

      it('should invalidate cache after successful commit', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        -- Populate cache
        index:staged_files()
        assert.is_not_nil(index._staged_files)

        index:commit('test commit')
        assert.is_nil(index._staged_files)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- can_commit
    -- -----------------------------------------------------------------------
    describe('can_commit', function()
      it('should return true when staged changes exist', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:can_commit()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should return false when no staged changes exist', function()
        local index = GitIndex(make_repo(repo))
        local result, err = index:can_commit()

        assert.is_nil(err)
        eq(false, result)
      end)

      it('should return false when changes are only unstaged', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified but not staged' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:can_commit()

        assert.is_nil(err)
        eq(false, result)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- staged_hunks / unstaged_hunks
    -- -----------------------------------------------------------------------
    describe('staged_hunks', function()
      it('should return hunks for a staged file', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed line one', 'line two', 'line three' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:staged_hunks('file1.txt')

        assert.is_nil(err)
        assert.is_true(#hunks > 0)
      end)

      it('should return empty list when file has no staged hunks', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed but not staged' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:staged_hunks('file1.txt')

        assert.is_nil(err)
        eq(0, #hunks)
      end)
    end)

    describe('unstaged_hunks', function()
      it('should return hunks for an unstaged modified file', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed line one', 'line two', 'line three' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:unstaged_hunks('file1.txt')

        assert.is_nil(err)
        assert.is_true(#hunks > 0)
      end)

      it('should return empty list when file has no unstaged hunks', function()
        test_repo.modify_file(repo, 'file1.txt', { 'staged change' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:unstaged_hunks('file1.txt')

        assert.is_nil(err)
        eq(0, #hunks)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- commit_dry_run
    -- -----------------------------------------------------------------------
    describe('commit_dry_run', function()
      it('should return output without making a commit', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:commit_dry_run()

        assert.is_nil(err)
        assert.is_not_nil(result)
        assert.is_true(#result > 0)

        -- The dry run should not actually commit; staging should remain
        local has_staged, staged_err = index:has_staged_changes()
        assert.is_nil(staged_err)
        eq(true, has_staged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- staged_files caching and invalidation
    -- -----------------------------------------------------------------------
    describe('staged_files caching', function()
      it('should cache results and return same reference', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local staged1, _ = index:staged_files()
        local staged2, _ = index:staged_files()

        assert.is_true(rawequal(staged1, staged2))
      end)

      it('should invalidate cache after add()', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        index:staged_files()
        assert.is_not_nil(index._staged_files)

        test_repo.modify_file(repo, 'file2.txt', { 'also modified' })
        index:add('file2.txt')
        assert.is_nil(index._staged_files)

        -- Now refetch; should have both files
        local staged, err = index:staged_files()
        assert.is_nil(err)
        eq(2, #staged)
      end)

      it('should invalidate cache after remove()', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        index:staged_files()
        assert.is_not_nil(index._staged_files)

        index:remove('file1.txt')
        assert.is_nil(index._staged_files)

        -- Now refetch; should be empty
        local staged, err = index:staged_files()
        assert.is_nil(err)
        eq(0, #staged)
      end)

      it('should invalidate cache after commit()', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        index:staged_files()
        assert.is_not_nil(index._staged_files)

        index:commit('test commit')
        assert.is_nil(index._staged_files)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- reset_cache with real data
    -- -----------------------------------------------------------------------
    describe('reset_cache with real data', function()
      it('should allow staged_files to refetch after reset_cache', function()
        test_repo.modify_file(repo, 'file1.txt', { 'modified' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local staged1, _ = index:staged_files()
        eq(1, #staged1)
        assert.is_not_nil(index._staged_files)

        index:reset_cache()
        assert.is_nil(index._staged_files)

        -- After reset_cache, next call should refetch
        local staged2, err = index:staged_files()
        assert.is_nil(err)
        eq(1, #staged2)
        -- Should not be the same object reference (refetched)
        assert.is_false(rawequal(staged1, staged2))
      end)
    end)

    -- -----------------------------------------------------------------------
    -- unmerged_files
    -- -----------------------------------------------------------------------
    describe('unmerged_files', function()
      it('should return empty list when no conflicts exist', function()
        local index = GitIndex(make_repo(repo))
        local unmerged, err = index:unmerged_files()

        assert.is_nil(err)
        eq(0, #unmerged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- add_hunk / remove_hunk integration
    -- -----------------------------------------------------------------------
    describe('add_hunk', function()
      it('should stage a specific hunk', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed line one', 'line two', 'line three' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:unstaged_hunks('file1.txt')
        assert.is_nil(err)
        assert.is_true(#hunks > 0)

        local result, add_err = index:add_hunk('file1.txt', hunks[1])
        assert.is_nil(add_err)
        eq(true, result)

        -- Verify it was staged
        local has, has_err = index:has_staged_changes()
        assert.is_nil(has_err)
        eq(true, has)
      end)
    end)

    describe('remove_hunk', function()
      it('should unstage a specific hunk', function()
        test_repo.modify_file(repo, 'file1.txt', { 'changed line one', 'line two', 'line three' })
        test_repo.stage(repo, { 'file1.txt' })

        local index = GitIndex(make_repo(repo))
        local hunks, err = index:staged_hunks('file1.txt')
        assert.is_nil(err)
        assert.is_true(#hunks > 0)

        local result, rm_err = index:remove_hunk('file1.txt', hunks[1])
        assert.is_nil(rm_err)
        eq(true, result)

        -- Verify it was unstaged
        index:reset_cache()
        local has, has_err = index:has_staged_changes()
        assert.is_nil(has_err)
        eq(false, has)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- file_status edge cases
    -- -----------------------------------------------------------------------
    describe('file_status edge cases', function()
      it('should return status for a deleted file', function()
        test_repo.delete_file(repo, 'file1.txt')

        local index = GitIndex(make_repo(repo))
        local file_info, err = index:file_status('file1.txt')

        assert.is_nil(err)
        assert.is_not_nil(file_info)
        eq('file1.txt', file_info.filename)
      end)

      it('should return status for an untracked file', function()
        test_repo.write_file(repo, 'brand_new.txt', { 'new content' })

        local index = GitIndex(make_repo(repo))
        local file_info, err = index:file_status('brand_new.txt')

        assert.is_nil(err)
        assert.is_not_nil(file_info)
        eq('brand_new.txt', file_info.filename)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- commit preserves unstaged changes
    -- -----------------------------------------------------------------------
    describe('commit edge cases', function()
      it('should preserve unstaged changes on same file after commit', function()
        -- First modification - stage it
        test_repo.modify_file(repo, 'file1.txt', { 'staged change' })
        test_repo.stage(repo, { 'file1.txt' })

        -- Second modification - don't stage
        test_repo.modify_file(repo, 'file1.txt', { 'unstaged change on top' })

        local index = GitIndex(make_repo(repo))
        local result, err = index:commit('partial commit')

        assert.is_nil(err)
        eq(true, result)

        -- After commit, there should still be unstaged changes
        local has_unstaged, unstaged_err = index:has_unstaged_changes()
        assert.is_nil(unstaged_err)
        eq(true, has_unstaged)
      end)
    end)

    -- -----------------------------------------------------------------------
    -- Full workflow integration
    -- -----------------------------------------------------------------------
    describe('full workflow', function()
      it('should handle modify -> stage -> commit cycle', function()
        local index = GitIndex(make_repo(repo))

        -- Start clean
        local clean1, _ = index:is_clean()
        eq(true, clean1)

        -- Modify a file
        test_repo.modify_file(repo, 'file1.txt', { 'workflow change' })

        -- Should no longer be clean
        local clean2, _ = index:is_clean()
        eq(false, clean2)

        -- Should have unstaged changes, not staged
        local has_unstaged, _ = index:has_unstaged_changes()
        eq(true, has_unstaged)

        index:reset_cache()
        local has_staged, _ = index:has_staged_changes()
        eq(false, has_staged)

        -- Stage the file via GitIndex:add
        index:add('file1.txt')

        -- Now should have staged changes and no unstaged
        local has_staged2, _ = index:has_staged_changes()
        eq(true, has_staged2)

        local has_unstaged2, _ = index:has_unstaged_changes()
        eq(false, has_unstaged2)

        -- Can commit should be true
        index:reset_cache()
        local can, _ = index:can_commit()
        eq(true, can)

        -- Commit
        local result, err = index:commit('workflow commit')
        assert.is_nil(err)
        eq(true, result)

        -- Should be clean again
        local clean3, _ = index:is_clean()
        eq(true, clean3)
      end)

      it('should handle stage -> unstage -> restage cycle', function()
        local index = GitIndex(make_repo(repo))

        test_repo.modify_file(repo, 'file1.txt', { 'cycle change' })

        -- Stage
        index:add('file1.txt')
        local staged1, _ = index:staged_files()
        eq(1, #staged1)

        -- Unstage
        index:remove('file1.txt')
        local staged2, _ = index:staged_files()
        eq(0, #staged2)

        -- Unstaged should still show the change
        local unstaged, _ = index:unstaged_files()
        eq(1, #unstaged)

        -- Restage
        index:add('file1.txt')
        local staged3, _ = index:staged_files()
        eq(1, #staged3)
      end)
    end)
  end)
end)
