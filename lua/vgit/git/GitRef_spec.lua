local GitRef = require('vgit.git.GitRef')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

local function make_repo(path)
  return { get_path = function() return path end }
end

describe('GitRef:', function()
  -- Unit tests (no repo needed)
  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitRef(nil)
      end)
    end)

    it('should create instance with valid repository', function()
      local r = GitRef(make_repo('/some/path'))
      eq(r._repo_path, '/some/path')
      assert.is_nil(r._branches)
      assert.is_nil(r._tags)
      assert.is_nil(r._current)
    end)

    it('should store the repository path from get_path()', function()
      local r = GitRef(make_repo('/another/path'))
      eq(r._repo_path, '/another/path')
    end)
  end)

  describe('reset_cache', function()
    it('should clear all caches', function()
      local r = GitRef(make_repo('/path'))
      r._branches = { { name = 'main', hash = 'abc' } }
      r._tags = { { name = 'v1.0.0', hash = 'def' } }
      r._current = { name = 'main', hash = 'abc', is_detached = false }

      r:reset_cache()

      assert.is_nil(r._branches)
      assert.is_nil(r._tags)
      assert.is_nil(r._current)
    end)

    it('should be safe to call when caches are already nil', function()
      local r = GitRef(make_repo('/path'))
      r._branches = nil
      r._tags = nil
      r._current = nil

      r:reset_cache()

      assert.is_nil(r._branches)
      assert.is_nil(r._tags)
      assert.is_nil(r._current)
    end)
  end)

  -- Parameter validation tests
  describe('parameter validation', function()
    it('get should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:get(nil)
      assert.is_nil(result)
      eq({ 'name is required' }, err)
    end)

    it('branch_exists should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:branch_exists(nil)
      assert.is_nil(result)
      eq({ 'name is required' }, err)
    end)

    it('tag_exists should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:tag_exists(nil)
      assert.is_nil(result)
      eq({ 'name is required' }, err)
    end)

    it('create_branch should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:create_branch(nil)
      assert.is_nil(result)
      eq({ 'branch name is required' }, err)
    end)

    it('delete_branch should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:delete_branch(nil)
      assert.is_nil(result)
      eq({ 'branch name is required' }, err)
    end)

    it('checkout should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:checkout(nil)
      assert.is_nil(result)
      eq({ 'name is required' }, err)
    end)

    it('checkout_new_branch should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:checkout_new_branch(nil)
      assert.is_nil(result)
      eq({ 'branch name is required' }, err)
    end)

    it('create_tag should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:create_tag(nil)
      assert.is_nil(result)
      eq({ 'tag name is required' }, err)
    end)

    it('delete_tag should error when name is nil', function()
      local r = GitRef(make_repo('/path'))
      local result, err = r:delete_tag(nil)
      assert.is_nil(result)
      eq({ 'tag name is required' }, err)
    end)
  end)

  -- Integration tests (real repo)
  describe('integration', function()
    local repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['file.txt'] = { 'content' } },
      })
      assert(not err, 'Failed to create test repo: ' .. tostring(err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
    end)

    describe('current', function()
      it('should return name, hash, and is_detached', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:current()

        assert.is_nil(err)
        assert.is_not_nil(result.name)
        assert.is_not_nil(result.hash)
        assert.is_false(result.is_detached)
      end)

      it('should cache the result on subsequent calls', function()
        local ref = GitRef(make_repo(repo))
        local result1, err1 = ref:current()
        local result2, err2 = ref:current()

        assert.is_nil(err1)
        assert.is_nil(err2)
        assert.equals(result1, result2)
      end)

      it('should detect detached HEAD', function()
        local commit_hash = test_repo.get_head_commit(repo)
        test_repo.detach_head(repo, commit_hash)

        local ref = GitRef(make_repo(repo))
        local result, err = ref:current()

        assert.is_nil(err)
        eq('HEAD', result.name)
        assert.is_true(result.is_detached)
      end)
    end)

    describe('current_branch', function()
      it('should return the branch name', function()
        local ref = GitRef(make_repo(repo))
        local name, err = ref:current_branch()

        assert.is_nil(err)
        assert.is_not_nil(name)
        assert.is_true(name == 'master' or name == 'main')
      end)
    end)

    describe('head', function()
      it('should return the HEAD hash', function()
        local ref = GitRef(make_repo(repo))
        local hash, err = ref:head()

        assert.is_nil(err)
        assert.is_not_nil(hash)
        assert.is_true(#hash >= 7)
      end)
    end)

    describe('is_detached', function()
      it('should return false when on a branch', function()
        local ref = GitRef(make_repo(repo))
        local detached, err = ref:is_detached()

        assert.is_nil(err)
        assert.is_false(detached)
      end)

      it('should return true when HEAD is detached', function()
        test_repo.detach_head(repo)

        local ref = GitRef(make_repo(repo))
        local detached, err = ref:is_detached()

        assert.is_nil(err)
        assert.is_true(detached)
      end)
    end)

    describe('branches', function()
      it('should list at least one branch', function()
        local ref = GitRef(make_repo(repo))
        local branches, err = ref:branches()

        assert.is_nil(err)
        assert.is_true(#branches >= 1)
        assert.is_not_nil(branches[1].name)
        assert.is_not_nil(branches[1].hash)
      end)

      it('should include created branches', function()
        test_repo.create_branch(repo, 'feature', { checkout = false })

        local ref = GitRef(make_repo(repo))
        local branches, err = ref:branches()

        assert.is_nil(err)
        assert.is_true(#branches >= 2)

        local found = false
        for _, b in ipairs(branches) do
          if b.name == 'feature' then
            found = true
            break
          end
        end
        assert.is_true(found)
      end)

      it('should cache result in _branches', function()
        local ref = GitRef(make_repo(repo))
        local branches, _ = ref:branches()

        eq(ref._branches, branches)
      end)
    end)

    describe('local_branches', function()
      it('should return local branches', function()
        local ref = GitRef(make_repo(repo))
        local branches, err = ref:local_branches()

        assert.is_nil(err)
        assert.is_true(#branches >= 1)
      end)
    end)

    describe('tags', function()
      it('should return empty when no tags exist', function()
        local ref = GitRef(make_repo(repo))
        local tags, err = ref:tags()

        assert.is_nil(err)
        eq(0, #tags)
      end)

      it('should list created tags', function()
        test_repo.create_tag(repo, 'v1.0.0')

        local ref = GitRef(make_repo(repo))
        local tags, err = ref:tags()

        assert.is_nil(err)
        eq(1, #tags)
        eq('v1.0.0', tags[1].name)
        assert.is_not_nil(tags[1].hash)
      end)

      it('should list multiple tags', function()
        test_repo.create_tag(repo, 'v1.0.0')
        test_repo.create_tag(repo, 'v2.0.0')

        local ref = GitRef(make_repo(repo))
        local tags, err = ref:tags()

        assert.is_nil(err)
        eq(2, #tags)
      end)

      it('should cache result on subsequent calls', function()
        test_repo.create_tag(repo, 'v1.0.0')

        local ref = GitRef(make_repo(repo))
        local tags1, _ = ref:tags()
        local tags2, _ = ref:tags()

        eq(tags1, tags2)
      end)
    end)

    describe('get', function()
      it('should return name and hash for valid ref', function()
        local ref = GitRef(make_repo(repo))
        local head_hash = test_repo.get_head_commit(repo)

        local result, err = ref:get('HEAD')

        assert.is_nil(err)
        eq('HEAD', result.name)
        assert.is_not_nil(result.hash)
      end)

      it('should work with branch names', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:get('master')

        if err then
          result, err = ref:get('main')
        end

        assert.is_nil(err)
        assert.is_not_nil(result.hash)
      end)

      it('should work with tag names', function()
        test_repo.create_tag(repo, 'v1.0.0')

        local ref = GitRef(make_repo(repo))
        local result, err = ref:get('v1.0.0')

        assert.is_nil(err)
        eq('v1.0.0', result.name)
        assert.is_not_nil(result.hash)
      end)
    end)

    describe('branch_exists', function()
      it('should return true when branch exists', function()
        local ref = GitRef(make_repo(repo))
        local exists, err = ref:branch_exists('master')

        if not exists then
          exists, err = ref:branch_exists('main')
        end

        assert.is_nil(err)
        assert.is_true(exists)
      end)

      it('should return false when branch does not exist', function()
        local ref = GitRef(make_repo(repo))
        local exists, err = ref:branch_exists('nonexistent-branch')

        assert.is_nil(err)
        assert.is_false(exists)
      end)
    end)

    describe('tag_exists', function()
      it('should return true when tag exists', function()
        test_repo.create_tag(repo, 'v1.0.0')

        local ref = GitRef(make_repo(repo))
        local exists, err = ref:tag_exists('v1.0.0')

        assert.is_nil(err)
        assert.is_true(exists)
      end)

      it('should return false when tag does not exist', function()
        local ref = GitRef(make_repo(repo))
        local exists, err = ref:tag_exists('nonexistent-tag')

        assert.is_nil(err)
        assert.is_false(exists)
      end)
    end)

    describe('create_branch', function()
      it('should create branch and return true', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:create_branch('new-feature')

        assert.is_nil(err)
        eq(true, result)

        -- Verify branch exists
        local exists, _ = ref:branch_exists('new-feature')
        assert.is_true(exists)
      end)

      it('should invalidate branches cache', function()
        local ref = GitRef(make_repo(repo))
        ref:branches()
        assert.is_not_nil(ref._branches)

        ref:create_branch('new-feature')
        assert.is_nil(ref._branches)
      end)

      it('should create branch at specific start_point', function()
        local ref = GitRef(make_repo(repo))
        local head_hash = test_repo.get_head_commit(repo)

        local result, err = ref:create_branch('from-commit', head_hash)

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:branch_exists('from-commit')
        assert.is_true(exists)
      end)
    end)

    describe('delete_branch', function()
      it('should delete branch and return true', function()
        local ref = GitRef(make_repo(repo))
        ref:create_branch('to-delete')

        local result, err = ref:delete_branch('to-delete')

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:branch_exists('to-delete')
        assert.is_false(exists)
      end)

      it('should invalidate branches cache', function()
        local ref = GitRef(make_repo(repo))
        ref:create_branch('to-delete')
        ref:branches()
        assert.is_not_nil(ref._branches)

        ref:delete_branch('to-delete')
        assert.is_nil(ref._branches)
      end)

      it('should use force delete when force is true', function()
        local ref = GitRef(make_repo(repo))
        ref:create_branch('force-delete')

        local result, err = ref:delete_branch('force-delete', true)

        assert.is_nil(err)
        eq(true, result)
      end)
    end)

    describe('checkout', function()
      it('should checkout existing branch', function()
        local ref = GitRef(make_repo(repo))
        ref:create_branch('checkout-target')

        local result, err = ref:checkout('checkout-target')

        assert.is_nil(err)
        eq(true, result)

        -- Verify we're on the new branch
        ref:reset_cache()
        local name, _ = ref:current_branch()
        eq('checkout-target', name)
      end)

      it('should invalidate current cache on success', function()
        local ref = GitRef(make_repo(repo))
        ref:current()
        assert.is_not_nil(ref._current)

        ref:create_branch('checkout-cache')
        ref:checkout('checkout-cache')
        assert.is_nil(ref._current)
      end)

      it('should return error for nonexistent branch', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:checkout('nonexistent-branch')

        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it('should not invalidate cache on error', function()
        local ref = GitRef(make_repo(repo))
        ref:current()
        local cached = ref._current

        ref:checkout('nonexistent-branch')
        eq(cached, ref._current)
      end)
    end)

    describe('checkout_new_branch', function()
      it('should create and checkout new branch', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:checkout_new_branch('new-feature')

        assert.is_nil(err)
        eq(true, result)

        ref:reset_cache()
        local name, _ = ref:current_branch()
        eq('new-feature', name)
      end)

      it('should invalidate both current and branches cache', function()
        local ref = GitRef(make_repo(repo))
        ref:current()
        ref:branches()
        assert.is_not_nil(ref._current)
        assert.is_not_nil(ref._branches)

        ref:checkout_new_branch('new-branch')

        assert.is_nil(ref._current)
        assert.is_nil(ref._branches)
      end)

      it('should create branch at specific start_point', function()
        local ref = GitRef(make_repo(repo))
        local head_hash = test_repo.get_head_commit(repo)

        local result, err = ref:checkout_new_branch('from-commit', head_hash)

        assert.is_nil(err)
        eq(true, result)

        ref:reset_cache()
        local name, _ = ref:current_branch()
        eq('from-commit', name)
      end)

      it('should not invalidate caches on error', function()
        local ref = GitRef(make_repo(repo))
        ref:current()
        ref:branches()
        local current_cache = ref._current
        local branches_cache = ref._branches

        -- Try to create branch with name that already exists
        -- The current branch (master/main) already exists
        local branch_name, _ = ref:current_branch()
        ref:checkout_new_branch(branch_name)

        eq(current_cache, ref._current)
        eq(branches_cache, ref._branches)
      end)
    end)

    describe('create_tag', function()
      it('should create lightweight tag and return true', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:create_tag('v1.0.0')

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:tag_exists('v1.0.0')
        assert.is_true(exists)
      end)

      it('should invalidate tags cache', function()
        local ref = GitRef(make_repo(repo))
        ref:tags()
        assert.is_not_nil(ref._tags)

        ref:create_tag('v1.0.0')
        assert.is_nil(ref._tags)
      end)

      it('should create annotated tag when message is provided', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:create_tag('v1.0.0', nil, 'Release 1.0.0')

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:tag_exists('v1.0.0')
        assert.is_true(exists)
      end)

      it('should create tag at specific commit', function()
        local ref = GitRef(make_repo(repo))
        local head_hash = test_repo.get_head_commit(repo)

        local result, err = ref:create_tag('v1.0.0', head_hash)

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:tag_exists('v1.0.0')
        assert.is_true(exists)
      end)

      it('should create annotated tag at specific commit', function()
        local ref = GitRef(make_repo(repo))
        local head_hash = test_repo.get_head_commit(repo)

        local result, err = ref:create_tag('v1.0.0', head_hash, 'Release message')

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:tag_exists('v1.0.0')
        assert.is_true(exists)
      end)

      it('should not invalidate cache on error', function()
        local ref = GitRef(make_repo(repo))
        ref:create_tag('v1.0.0')
        ref:tags()
        assert.is_not_nil(ref._tags)

        -- Creating a tag with same name should fail
        ref:create_tag('v1.0.0')
        assert.is_not_nil(ref._tags)
      end)
    end)

    describe('delete_tag', function()
      it('should delete tag and return true', function()
        local ref = GitRef(make_repo(repo))
        ref:create_tag('v1.0.0')

        local result, err = ref:delete_tag('v1.0.0')

        assert.is_nil(err)
        eq(true, result)

        local exists, _ = ref:tag_exists('v1.0.0')
        assert.is_false(exists)
      end)

      it('should invalidate tags cache', function()
        local ref = GitRef(make_repo(repo))
        ref:create_tag('v1.0.0')
        ref:tags()
        assert.is_not_nil(ref._tags)

        ref:delete_tag('v1.0.0')
        assert.is_nil(ref._tags)
      end)

      it('should return error for nonexistent tag', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:delete_tag('nonexistent-tag')

        assert.is_nil(result)
        assert.is_not_nil(err)
      end)

      it('should not invalidate cache on error', function()
        local ref = GitRef(make_repo(repo))
        ref:create_tag('v1.0.0')
        ref:tags()
        assert.is_not_nil(ref._tags)

        ref:delete_tag('nonexistent-tag')
        assert.is_not_nil(ref._tags)
      end)
    end)

    describe('get edge cases', function()
      it('should return error for non-existent ref', function()
        local ref = GitRef(make_repo(repo))
        local result, err = ref:get('nonexistent-ref-12345')

        assert.is_nil(result)
        assert.is_not_nil(err)
      end)
    end)

    describe('create_tag edge cases', function()
      it('should return error when creating duplicate tag', function()
        local ref = GitRef(make_repo(repo))
        local result1, err1 = ref:create_tag('v-duplicate')

        assert.is_nil(err1)
        eq(true, result1)

        -- Creating the same tag again should fail
        local result2, err2 = ref:create_tag('v-duplicate')
        assert.is_nil(result2)
        assert.is_not_nil(err2)
      end)
    end)

    describe('reset_cache with real data', function()
      it('should allow fresh data to be fetched after reset', function()
        local ref = GitRef(make_repo(repo))

        -- Fetch and cache tags
        ref:tags()
        assert.is_not_nil(ref._tags)

        -- Create a new tag
        test_repo.create_tag(repo, 'v2.0.0')

        -- Reset cache and re-fetch
        ref:reset_cache()
        local tags, err = ref:tags()

        assert.is_nil(err)
        eq(1, #tags)
        eq('v2.0.0', tags[1].name)
      end)
    end)
  end)
end)
