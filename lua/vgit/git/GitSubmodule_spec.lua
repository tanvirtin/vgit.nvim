local GitSubmodule = require('vgit.git.GitSubmodule')
local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')
local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })

local eq = assert.are.same

local function make_repo(path)
  path = path or '/repo'
  return { get_path = function() return path end }
end

describe('GitSubmodule', function()
  -- Unit tests (no repo needed)
  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitSubmodule(nil, 'libs/foo')
      end, 'GitSubmodule requires a repository')
    end)

    it('should error when path is nil', function()
      assert.has_error(function()
        GitSubmodule(make_repo(), nil)
      end, 'GitSubmodule requires a path')
    end)

    it('should create instance with valid args', function()
      local sub = GitSubmodule(make_repo('/repo'), 'libs/foo')

      assert.is_not_nil(sub)
      eq('/repo', sub._repo_path)
      eq('libs/foo', sub._path)
      assert.is_nil(sub._info)
    end)
  end)

  describe('path', function()
    it('should return the path', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')

      eq('libs/foo', sub:path())
    end)
  end)

  describe('set_url', function()
    it('should validate url is required', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      local result, err = sub:set_url(nil)

      assert.is_nil(result)
      eq({ 'url is required' }, err)
    end)

    it('should not invalidate cache when url is nil', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub._info = { some = 'data' }

      sub:set_url(nil)
      assert.is_not_nil(sub._info)
    end)
  end)

  describe('reset_cache', function()
    it('should clear _info', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      sub._info = { some = 'data' }

      sub:reset_cache()
      assert.is_nil(sub._info)
    end)

    it('should be safe to call when _info is already nil', function()
      local sub = GitSubmodule(make_repo(), 'libs/foo')
      assert.is_nil(sub._info)

      sub:reset_cache()
      assert.is_nil(sub._info)
    end)
  end)

  -- Integration tests
  describe('integration', function()
    local repo
    local source_repo
    local it = async.it
    local before_each = async.before_each
    local after_each = async.after_each

    before_each(function()
      local err

      -- Create source repo to be used as submodule
      source_repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['lib.txt'] = { 'library content' } },
      })
      assert(not err, 'Failed to create source repo: ' .. tostring(err))

      -- Create main repo
      repo, err = test_repo.create_repo({
        initial_commit = true,
        files = { ['main.txt'] = { 'main content' } },
      })
      assert(not err, 'Failed to create main repo: ' .. tostring(err))

      -- Add submodule to main repo
      local _, sub_err = test_repo.add_submodule(repo, source_repo, 'libs/dep')
      assert(not sub_err, 'Failed to add submodule: ' .. tostring(sub_err))
    end)

    after_each(function()
      if repo then test_repo.cleanup(repo) end
      if source_repo then test_repo.cleanup(source_repo) end
    end)

    describe('info', function()
      it('should return submodule info with correct path', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local info, err = sub:info()

        assert.is_nil(err)
        assert.is_not_nil(info)
        eq('libs/dep', info.path)
      end)

      it('should return submodule info with a hash', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local info, err = sub:info()

        assert.is_nil(err)
        assert.is_not_nil(info.hash)
        assert.is_true(type(info.hash) == 'string')
        assert.is_true(#info.hash > 0)
      end)

      it('should return initialized status for a freshly added submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local info, err = sub:info()

        assert.is_nil(err)
        eq('initialized', info.status)
      end)

      it('should return error for nonexistent submodule path', function()
        local sub = GitSubmodule(make_repo(repo), 'nonexistent/path')
        local info, err = sub:info()

        assert.is_nil(info)
        assert.is_not_nil(err)
        eq({ 'submodule not found: nonexistent/path' }, err)
      end)

      it('should cache info after first call', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local info1, err1 = sub:info()
        local info2, err2 = sub:info()

        assert.is_nil(err1)
        assert.is_nil(err2)
        assert.is_true(rawequal(info1, info2))
      end)
    end)

    describe('status', function()
      it('should return initialized for a freshly added submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local status, err = sub:status()

        assert.is_nil(err)
        eq('initialized', status)
      end)
    end)

    describe('hash', function()
      it('should return a valid commit hash', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local hash, err = sub:hash()

        assert.is_nil(err)
        assert.is_not_nil(hash)
        assert.is_true(type(hash) == 'string')
        -- Git hashes are 40 hex chars
        assert.is_true(#hash == 40, 'Expected 40 char hash, got ' .. #hash)
        assert.is_true(hash:match('^[0-9a-f]+$') ~= nil)
      end)
    end)

    describe('ref', function()
      it('should return ref if available', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local ref, err = sub:ref()

        assert.is_nil(err)
        -- ref may or may not be set depending on the submodule state;
        -- for a freshly added submodule it may be nil or a branch/tag name
        -- we just verify no error occurs
      end)
    end)

    describe('is_initialized', function()
      it('should return true for an initialized submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        assert.is_true(sub:is_initialized())
      end)

      it('should return false for a nonexistent submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'nonexistent/path')

        -- info() will error, is_initialized returns false on error
        assert.is_false(sub:is_initialized())
      end)
    end)

    describe('is_modified', function()
      it('should return false for a clean submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        assert.is_false(sub:is_modified())
      end)
    end)

    describe('has_conflicts', function()
      it('should return false for a clean submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        assert.is_false(sub:has_conflicts())
      end)
    end)

    describe('update', function()
      it('should succeed on an already initialized submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local result, err = sub:update()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should invalidate cache after success', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        -- Update should clear cache
        sub:update()
        assert.is_nil(sub._info)
      end)
    end)

    describe('sync', function()
      it('should succeed on an already initialized submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local result, err = sub:sync()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should invalidate cache after success', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        -- Sync should clear cache
        sub:sync()
        assert.is_nil(sub._info)
      end)
    end)

    describe('init', function()
      it('should succeed on an already initialized submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local result, err = sub:init()

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should invalidate cache after success', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        -- Init should clear cache
        sub:init()
        assert.is_nil(sub._info)
      end)
    end)

    describe('set_branch', function()
      it('should succeed setting a branch on the submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local result, err = sub:set_branch('main')

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should invalidate cache after success', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        -- set_branch should clear cache
        sub:set_branch('main')
        assert.is_nil(sub._info)
      end)
    end)

    describe('set_url', function()
      it('should succeed setting a URL on the submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')
        local result, err = sub:set_url(source_repo)

        assert.is_nil(err)
        eq(true, result)
      end)

      it('should invalidate cache after success', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        -- set_url should clear cache
        sub:set_url(source_repo)
        assert.is_nil(sub._info)
      end)
    end)

    describe('deinit', function()
      it('should succeed with force and clear cache', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Populate cache
        local info, info_err = sub:info()
        assert.is_nil(info_err)
        assert.is_not_nil(sub._info)

        local result, err = sub:deinit({ force = true })
        assert.is_nil(err)
        eq(true, result)

        -- Cache should be cleared after deinit
        assert.is_nil(sub._info)
      end)

      it('should succeed without force on clean submodule', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- deinit without force succeeds on clean submodule
        local result, err = sub:deinit()

        assert.is_nil(err)
        eq(true, result)
      end)
    end)

    describe('is_modified edge cases', function()
      it('should return true when submodule has local changes', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Create a commit inside the submodule to make it "modified"
        vim.fn.system({
          'git', '-C', repo .. '/libs/dep',
          'commit', '-q', '--allow-empty', '-m', 'local-change',
        })

        -- Reset cache to pick up new state
        sub:reset_cache()
        assert.is_true(sub:is_modified())
      end)
    end)

    describe('reset_cache with real data', function()
      it('should clear cached info and allow re-fetch', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- Fetch and cache
        local info1, err1 = sub:info()
        assert.is_nil(err1)
        assert.is_not_nil(sub._info)

        -- Reset cache
        sub:reset_cache()
        assert.is_nil(sub._info)

        -- Re-fetch should produce fresh (but equivalent) data
        local info2, err2 = sub:info()
        assert.is_nil(err2)
        assert.is_not_nil(info2)

        -- The re-fetched data should NOT be the same table reference
        assert.is_false(rawequal(info1, info2))

        -- But the values should match
        eq(info1.path, info2.path)
        eq(info1.hash, info2.hash)
        eq(info1.status, info2.status)
      end)
    end)

    describe('info caching across methods', function()
      it('should share cached info between status, hash, and ref calls', function()
        local sub = GitSubmodule(make_repo(repo), 'libs/dep')

        -- First call populates cache
        local status, err = sub:status()
        assert.is_nil(err)
        assert.is_not_nil(sub._info)

        local cached_ref = sub._info

        -- Subsequent calls should reuse the same cached table
        local hash, hash_err = sub:hash()
        assert.is_nil(hash_err)
        assert.is_true(rawequal(cached_ref, sub._info))

        local ref, ref_err = sub:ref()
        assert.is_nil(ref_err)
        assert.is_true(rawequal(cached_ref, sub._info))
      end)
    end)
  end)
end)
