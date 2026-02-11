-- Stub GitQueryBuilder and git_repo before requiring GitRef.
-- GitRef calls GitQueryBuilder at the module level (via require), so we
-- inject our mock into package.loaded first.

local mock_execute_result = {}
local mock_execute_err = nil
local mock_raw_args_calls = {}
local mock_raw_arg_calls = {}
local mock_checkout_result = nil
local mock_checkout_err = nil
local mock_checkout_calls = {}

local function make_chain_builder()
  local b = {}
  local chain_mt = {
    __index = function(_, key)
      if key == 'execute' then
        return function()
          return mock_execute_result, mock_execute_err
        end
      end
      if key == 'raw_args' then
        return function(self_or_b, ...)
          mock_raw_args_calls[#mock_raw_args_calls + 1] = { ... }
          return b
        end
      end
      if key == 'raw_arg' then
        return function(self_or_b, arg)
          mock_raw_arg_calls[#mock_raw_arg_calls + 1] = arg
          return b
        end
      end
      -- All other methods return self for chaining
      return function()
        return b
      end
    end,
  }
  setmetatable(b, chain_mt)
  return b
end

local mock_builder = {}
setmetatable(mock_builder, {
  __call = function(_, repo_path)
    return make_chain_builder()
  end,
})

-- Also make it behave like the Object-based module (has extend, etc.)
-- GitRef only needs it as a callable, so the metatable __call is sufficient.

local real_git_query_builder = package.loaded['vgit.git.GitQueryBuilder']
local real_git_repo = package.loaded['vgit.git.git_repo']

package.loaded['vgit.git.GitQueryBuilder'] = mock_builder
package.loaded['vgit.git.git_repo'] = {
  checkout = function(repo_path, name)
    mock_checkout_calls[#mock_checkout_calls + 1] = { repo_path = repo_path, name = name }
    return mock_checkout_result, mock_checkout_err
  end,
}

-- Now require GitRef - it will pick up our stubs
package.loaded['vgit.git.GitRef'] = nil
local GitRef = require('vgit.git.GitRef')

local eq = assert.are.same

-- Helper: create a mock repository object
local function make_repo(path)
  return {
    get_path = function()
      return path or '/mock/repo'
    end,
  }
end

describe('GitRef:', function()
  local ref

  before_each(function()
    mock_execute_result = {}
    mock_execute_err = nil
    mock_raw_args_calls = {}
    mock_raw_arg_calls = {}
    mock_checkout_result = nil
    mock_checkout_err = nil
    mock_checkout_calls = {}
    ref = GitRef(make_repo('/mock/repo'))
  end)

  after_each(function()
    -- nothing to clean up since we use fresh instances
  end)

  describe('constructor', function()
    it('should error when repository is nil', function()
      assert.has_error(function()
        GitRef(nil)
      end)
    end)

    it('should create instance with valid repository', function()
      local r = GitRef(make_repo('/some/path'))

      eq(r._repo_path, '/some/path')
      eq(r._branches, nil)
      eq(r._tags, nil)
      eq(r._current, nil)
    end)

    it('should store the repository path from get_path()', function()
      local r = GitRef(make_repo('/another/path'))

      eq(r._repo_path, '/another/path')
    end)
  end)

  describe('current()', function()
    it('should return name, hash, and is_detached', function()
      -- current() calls execute() twice: once for branch name, once for hash
      local call_count = 0
      local original_builder_call = getmetatable(mock_builder).__call
      getmetatable(mock_builder).__call = function(_, repo_path)
        local b = {}
        local bmt = {
          __index = function(_, key)
            if key == 'execute' then
              return function()
                call_count = call_count + 1
                if call_count == 1 then
                  return { 'main' }, nil
                else
                  return { 'abc123def456' }, nil
                end
              end
            end
            return function()
              return b
            end
          end,
        }
        setmetatable(b, bmt)
        return b
      end

      local result, err = ref:current()

      assert.is_nil(err)
      eq(result.name, 'main')
      eq(result.hash, 'abc123def456')
      eq(result.is_detached, false)

      -- Restore
      getmetatable(mock_builder).__call = original_builder_call
    end)

    it('should cache the result on subsequent calls', function()
      local call_count = 0
      local original_builder_call = getmetatable(mock_builder).__call
      getmetatable(mock_builder).__call = function(_, repo_path)
        local b = {}
        local bmt = {
          __index = function(_, key)
            if key == 'execute' then
              return function()
                call_count = call_count + 1
                if call_count == 1 then
                  return { 'main' }, nil
                elseif call_count == 2 then
                  return { 'abc123' }, nil
                else
                  -- Should not reach here if caching works
                  return { 'unexpected' }, nil
                end
              end
            end
            return function()
              return b
            end
          end,
        }
        setmetatable(b, bmt)
        return b
      end

      local result1, err1 = ref:current()
      local result2, err2 = ref:current()

      assert.is_nil(err1)
      assert.is_nil(err2)
      -- Same reference due to caching
      assert.equals(result1, result2)
      -- Only 2 execute calls (not 4)
      eq(call_count, 2)

      getmetatable(mock_builder).__call = original_builder_call
    end)

    it('should propagate error from first execute (branch name)', function()
      mock_execute_err = { 'fatal: not a git repository' }

      local result, err = ref:current()

      assert.is_nil(result)
      eq(err, { 'fatal: not a git repository' })
    end)

    it('should propagate error from second execute (hash)', function()
      local call_count = 0
      local original_builder_call = getmetatable(mock_builder).__call
      getmetatable(mock_builder).__call = function(_, repo_path)
        local b = {}
        local bmt = {
          __index = function(_, key)
            if key == 'execute' then
              return function()
                call_count = call_count + 1
                if call_count == 1 then
                  return { 'main' }, nil
                else
                  return nil, { 'hash error' }
                end
              end
            end
            return function()
              return b
            end
          end,
        }
        setmetatable(b, bmt)
        return b
      end

      local result, err = ref:current()

      assert.is_nil(result)
      eq(err, { 'hash error' })

      getmetatable(mock_builder).__call = original_builder_call
    end)

    it('should detect detached HEAD', function()
      local call_count = 0
      local original_builder_call = getmetatable(mock_builder).__call
      getmetatable(mock_builder).__call = function(_, repo_path)
        local b = {}
        local bmt = {
          __index = function(_, key)
            if key == 'execute' then
              return function()
                call_count = call_count + 1
                if call_count == 1 then
                  return { 'HEAD' }, nil
                else
                  return { 'deadbeef1234' }, nil
                end
              end
            end
            return function()
              return b
            end
          end,
        }
        setmetatable(b, bmt)
        return b
      end

      local result, err = ref:current()

      assert.is_nil(err)
      eq(result.name, 'HEAD')
      eq(result.hash, 'deadbeef1234')
      eq(result.is_detached, true)

      getmetatable(mock_builder).__call = original_builder_call
    end)
  end)

  describe('current_branch()', function()
    it('should return the branch name', function()
      -- Pre-populate the cache
      ref._current = { name = 'feature-x', hash = 'abc', is_detached = false }

      local name, err = ref:current_branch()

      assert.is_nil(err)
      eq(name, 'feature-x')
    end)

    it('should propagate errors from current()', function()
      mock_execute_err = { 'some error' }

      local name, err = ref:current_branch()

      assert.is_nil(name)
      eq(err, { 'some error' })
    end)
  end)

  describe('head()', function()
    it('should return the HEAD hash', function()
      ref._current = { name = 'main', hash = 'deadbeef', is_detached = false }

      local hash, err = ref:head()

      assert.is_nil(err)
      eq(hash, 'deadbeef')
    end)

    it('should propagate errors from current()', function()
      mock_execute_err = { 'error' }

      local hash, err = ref:head()

      assert.is_nil(hash)
      eq(err, { 'error' })
    end)
  end)

  describe('is_detached()', function()
    it('should return true when HEAD is detached', function()
      ref._current = { name = 'HEAD', hash = 'abc', is_detached = true }

      local detached, err = ref:is_detached()

      assert.is_nil(err)
      eq(detached, true)
    end)

    it('should return false when on a branch', function()
      ref._current = { name = 'main', hash = 'abc', is_detached = false }

      local detached, err = ref:is_detached()

      assert.is_nil(err)
      eq(detached, false)
    end)

    it('should propagate errors from current()', function()
      mock_execute_err = { 'fail' }

      local detached, err = ref:is_detached()

      assert.is_nil(detached)
      eq(err, { 'fail' })
    end)
  end)

  describe('branches()', function()
    it('should parse output lines with unit separator', function()
      mock_execute_result = {
        'main\x1Fabc123',
        'feature\x1Fdef456',
        'bugfix\x1Fghi789',
      }

      local branches, err = ref:branches()

      assert.is_nil(err)
      eq(#branches, 3)
      eq(branches[1].name, 'main')
      eq(branches[1].hash, 'abc123')
      eq(branches[2].name, 'feature')
      eq(branches[2].hash, 'def456')
      eq(branches[3].name, 'bugfix')
      eq(branches[3].hash, 'ghi789')
    end)

    it('should set is_remote to false for local branches', function()
      mock_execute_result = {
        'main\x1Fabc123',
      }

      local branches, err = ref:branches()

      assert.is_nil(err)
      -- When neither remote nor all is set, is_remote should be nil/false
      assert.is_falsy(branches[1].is_remote)
    end)

    it('should set is_remote to true for remote branches', function()
      mock_execute_result = {
        'origin/main\x1Fabc123',
      }

      local branches, err = ref:branches({ remote = true })

      assert.is_nil(err)
      eq(branches[1].is_remote, true)
    end)

    it('should handle empty result', function()
      mock_execute_result = {}

      local branches, err = ref:branches()

      assert.is_nil(err)
      eq(branches, {})
    end)

    it('should skip lines with fewer than 2 parts', function()
      mock_execute_result = {
        'main\x1Fabc123',
        'malformed-line',
        'feature\x1Fdef456',
      }

      local branches, err = ref:branches()

      assert.is_nil(err)
      eq(#branches, 2)
      eq(branches[1].name, 'main')
      eq(branches[2].name, 'feature')
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'branch error' }

      local branches, err = ref:branches()

      assert.is_nil(branches)
      eq(err, { 'branch error' })
    end)

    it('should cache result in _branches', function()
      mock_execute_result = { 'main\x1Fabc123' }

      local branches, _ = ref:branches()

      eq(ref._branches, branches)
    end)

    it('should handle all option for mixed local and remote', function()
      mock_execute_result = {
        'main\x1Fabc123',
        'remotes/origin/main\x1Fdef456',
      }

      local branches, err = ref:branches({ all = true })

      assert.is_nil(err)
      eq(#branches, 2)
      -- First one is local (no remotes/ prefix)
      assert.is_falsy(branches[1].is_remote)
      -- Second one has remotes/ prefix, so is_remote should be truthy
      assert.is_truthy(branches[2].is_remote)
    end)
  end)

  describe('local_branches()', function()
    it('should delegate to branches with remote=false', function()
      mock_execute_result = { 'main\x1Fabc123' }

      local branches, err = ref:local_branches()

      assert.is_nil(err)
      eq(#branches, 1)
      eq(branches[1].name, 'main')
    end)
  end)

  describe('remote_branches()', function()
    it('should delegate to branches with remote=true', function()
      mock_execute_result = { 'origin/main\x1Fabc123' }

      local branches, err = ref:remote_branches()

      assert.is_nil(err)
      eq(#branches, 1)
      eq(branches[1].name, 'origin/main')
      eq(branches[1].is_remote, true)
    end)
  end)

  describe('tags()', function()
    it('should parse output lines with unit separator', function()
      mock_execute_result = {
        'v1.0.0\x1Fabc123',
        'v2.0.0\x1Fdef456',
      }

      local tags, err = ref:tags()

      assert.is_nil(err)
      eq(#tags, 2)
      eq(tags[1].name, 'v1.0.0')
      eq(tags[1].hash, 'abc123')
      eq(tags[2].name, 'v2.0.0')
      eq(tags[2].hash, 'def456')
    end)

    it('should cache result on subsequent calls', function()
      mock_execute_result = { 'v1.0.0\x1Fabc123' }

      local tags1, _ = ref:tags()

      -- Change mock result - should not matter due to caching
      mock_execute_result = { 'v2.0.0\x1Fdef456' }

      local tags2, _ = ref:tags()

      eq(tags1, tags2)
      eq(#tags2, 1)
      eq(tags2[1].name, 'v1.0.0')
    end)

    it('should handle empty result', function()
      mock_execute_result = {}

      local tags, err = ref:tags()

      assert.is_nil(err)
      eq(tags, {})
    end)

    it('should skip lines with fewer than 2 parts', function()
      mock_execute_result = {
        'v1.0.0\x1Fabc123',
        'malformed',
        'v2.0.0\x1Fdef456',
      }

      local tags, err = ref:tags()

      assert.is_nil(err)
      eq(#tags, 2)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'tag error' }

      local tags, err = ref:tags()

      assert.is_nil(tags)
      eq(err, { 'tag error' })
    end)
  end)

  describe('get()', function()
    it('should error when name is nil', function()
      local result, err = ref:get(nil)

      assert.is_nil(result)
      eq(err, { 'name is required' })
    end)

    it('should return name and hash for valid ref', function()
      mock_execute_result = { 'abc123def456' }

      local result, err = ref:get('main')

      assert.is_nil(err)
      eq(result.name, 'main')
      eq(result.hash, 'abc123def456')
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'fatal: not a valid ref' }

      local result, err = ref:get('nonexistent')

      assert.is_nil(result)
      eq(err, { 'fatal: not a valid ref' })
    end)

    it('should work with tag names', function()
      mock_execute_result = { 'tag_hash_123' }

      local result, err = ref:get('v1.0.0')

      assert.is_nil(err)
      eq(result.name, 'v1.0.0')
      eq(result.hash, 'tag_hash_123')
    end)

    it('should work with commit hashes', function()
      mock_execute_result = { 'abc123' }

      local result, err = ref:get('abc123')

      assert.is_nil(err)
      eq(result.name, 'abc123')
      eq(result.hash, 'abc123')
    end)
  end)

  describe('branch_exists()', function()
    it('should error when name is nil', function()
      local result, err = ref:branch_exists(nil)

      assert.is_nil(result)
      eq(err, { 'name is required' })
    end)

    it('should return true when branch exists (no error)', function()
      mock_execute_result = { 'abc123' }
      mock_execute_err = nil

      local exists, err = ref:branch_exists('main')

      assert.is_nil(err)
      eq(exists, true)
    end)

    it('should return false when branch does not exist (error)', function()
      mock_execute_err = { 'fatal: not a valid object name' }

      local exists, err = ref:branch_exists('nonexistent')

      assert.is_nil(err)
      eq(exists, false)
    end)
  end)

  describe('tag_exists()', function()
    it('should error when name is nil', function()
      local result, err = ref:tag_exists(nil)

      assert.is_nil(result)
      eq(err, { 'name is required' })
    end)

    it('should return true when tag exists (no error)', function()
      mock_execute_result = { 'abc123' }
      mock_execute_err = nil

      local exists, err = ref:tag_exists('v1.0.0')

      assert.is_nil(err)
      eq(exists, true)
    end)

    it('should return false when tag does not exist (error)', function()
      mock_execute_err = { 'fatal: not a valid object name' }

      local exists, err = ref:tag_exists('nonexistent')

      assert.is_nil(err)
      eq(exists, false)
    end)
  end)

  describe('create_branch()', function()
    it('should error when name is nil', function()
      local result, err = ref:create_branch(nil)

      assert.is_nil(result)
      eq(err, { 'branch name is required' })
    end)

    it('should create branch and return true', function()
      mock_execute_result = {}
      mock_execute_err = nil

      local result, err = ref:create_branch('new-feature')

      assert.is_nil(err)
      eq(result, true)
    end)

    it('should invalidate branches cache', function()
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_branch('new-feature')

      assert.is_nil(ref._branches)
    end)

    it('should pass start_point as raw_arg when provided', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_branch('new-feature', 'abc123')

      -- start_point should have been passed via raw_arg
      local found = false
      for _, arg in ipairs(mock_raw_arg_calls) do
        if arg == 'abc123' then
          found = true
          break
        end
      end
      eq(found, true)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'fatal: branch already exists' }

      local result, err = ref:create_branch('existing')

      assert.is_nil(result)
      eq(err, { 'fatal: branch already exists' })
    end)

    it('should not invalidate cache on error', function()
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_err = { 'error' }

      ref:create_branch('bad')

      -- Cache should still be set since error occurred before invalidation
      eq(#ref._branches, 1)
    end)
  end)

  describe('delete_branch()', function()
    it('should error when name is nil', function()
      local result, err = ref:delete_branch(nil)

      assert.is_nil(result)
      eq(err, { 'branch name is required' })
    end)

    it('should delete branch and return true', function()
      mock_execute_result = {}
      mock_execute_err = nil

      local result, err = ref:delete_branch('old-feature')

      assert.is_nil(err)
      eq(result, true)
    end)

    it('should invalidate branches cache', function()
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_result = {}
      mock_execute_err = nil

      ref:delete_branch('old-feature')

      assert.is_nil(ref._branches)
    end)

    it('should use -d flag by default (non-force)', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:delete_branch('feature')

      -- We check raw_args_calls to see if -d was passed
      local found_d = false
      for _, args in ipairs(mock_raw_args_calls) do
        for _, a in ipairs(args) do
          if a == '-d' then
            found_d = true
          end
        end
      end
      eq(found_d, true)
    end)

    it('should use -D flag when force is true', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:delete_branch('feature', true)

      local found_D = false
      for _, args in ipairs(mock_raw_args_calls) do
        for _, a in ipairs(args) do
          if a == '-D' then
            found_D = true
          end
        end
      end
      eq(found_D, true)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'cannot delete' }

      local result, err = ref:delete_branch('protected')

      assert.is_nil(result)
      eq(err, { 'cannot delete' })
    end)

    it('should not invalidate cache on error', function()
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_err = { 'error' }

      ref:delete_branch('bad')

      eq(#ref._branches, 1)
    end)
  end)

  describe('checkout()', function()
    it('should error when name is nil', function()
      local result, err = ref:checkout(nil)

      assert.is_nil(result)
      eq(err, { 'name is required' })
    end)

    it('should delegate to git_repo.checkout', function()
      mock_checkout_result = true
      mock_checkout_err = nil

      local result, err = ref:checkout('feature')

      assert.is_nil(err)
      eq(result, true)
      eq(#mock_checkout_calls, 1)
      eq(mock_checkout_calls[1].repo_path, '/mock/repo')
      eq(mock_checkout_calls[1].name, 'feature')
    end)

    it('should invalidate current cache on success', function()
      ref._current = { name = 'main', hash = 'abc', is_detached = false }
      mock_checkout_result = true
      mock_checkout_err = nil

      ref:checkout('feature')

      assert.is_nil(ref._current)
    end)

    it('should propagate errors from git_repo.checkout', function()
      mock_checkout_err = { 'checkout failed' }

      local result, err = ref:checkout('nonexistent')

      assert.is_nil(result)
      eq(err, { 'checkout failed' })
    end)

    it('should not invalidate cache on error', function()
      ref._current = { name = 'main', hash = 'abc', is_detached = false }
      mock_checkout_err = { 'error' }

      ref:checkout('bad')

      eq(ref._current.name, 'main')
    end)
  end)

  describe('checkout_new_branch()', function()
    it('should error when name is nil', function()
      local result, err = ref:checkout_new_branch(nil)

      assert.is_nil(result)
      eq(err, { 'branch name is required' })
    end)

    it('should create and checkout new branch', function()
      mock_execute_result = {}
      mock_execute_err = nil

      local result, err = ref:checkout_new_branch('new-feature')

      assert.is_nil(err)
      eq(result, true)
    end)

    it('should invalidate both current and branches cache', function()
      ref._current = { name = 'main', hash = 'abc', is_detached = false }
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_result = {}
      mock_execute_err = nil

      ref:checkout_new_branch('new-feature')

      assert.is_nil(ref._current)
      assert.is_nil(ref._branches)
    end)

    it('should pass start_point as raw_arg when provided', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:checkout_new_branch('new-feature', 'abc123')

      local found = false
      for _, arg in ipairs(mock_raw_arg_calls) do
        if arg == 'abc123' then
          found = true
          break
        end
      end
      eq(found, true)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'branch exists' }

      local result, err = ref:checkout_new_branch('existing')

      assert.is_nil(result)
      eq(err, { 'branch exists' })
    end)

    it('should not invalidate caches on error', function()
      ref._current = { name = 'main', hash = 'abc', is_detached = false }
      ref._branches = { { name = 'main', hash = 'abc' } }
      mock_execute_err = { 'error' }

      ref:checkout_new_branch('bad')

      eq(ref._current.name, 'main')
      eq(#ref._branches, 1)
    end)
  end)

  describe('create_tag()', function()
    it('should error when name is nil', function()
      local result, err = ref:create_tag(nil)

      assert.is_nil(result)
      eq(err, { 'tag name is required' })
    end)

    it('should create lightweight tag and return true', function()
      mock_execute_result = {}
      mock_execute_err = nil

      local result, err = ref:create_tag('v1.0.0')

      assert.is_nil(err)
      eq(result, true)
    end)

    it('should invalidate tags cache', function()
      ref._tags = { { name = 'v0.9.0', hash = 'old' } }
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_tag('v1.0.0')

      assert.is_nil(ref._tags)
    end)

    it('should create annotated tag when message is provided', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_tag('v1.0.0', nil, 'Release 1.0.0')

      -- Should have called raw_arg with '-a', tag name, '-m', and message
      local found_a = false
      local found_m = false
      local found_msg = false
      for _, arg in ipairs(mock_raw_arg_calls) do
        if arg == '-a' then found_a = true end
        if arg == '-m' then found_m = true end
        if arg == 'Release 1.0.0' then found_msg = true end
      end
      eq(found_a, true)
      eq(found_m, true)
      eq(found_msg, true)
    end)

    it('should pass commit as raw_arg when provided', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_tag('v1.0.0', 'abc123')

      local found = false
      for _, arg in ipairs(mock_raw_arg_calls) do
        if arg == 'abc123' then
          found = true
          break
        end
      end
      eq(found, true)
    end)

    it('should handle annotated tag with commit', function()
      mock_execute_result = {}
      mock_execute_err = nil

      ref:create_tag('v1.0.0', 'abc123', 'Release message')

      local found_a = false
      local found_commit = false
      local found_msg = false
      for _, arg in ipairs(mock_raw_arg_calls) do
        if arg == '-a' then found_a = true end
        if arg == 'abc123' then found_commit = true end
        if arg == 'Release message' then found_msg = true end
      end
      eq(found_a, true)
      eq(found_commit, true)
      eq(found_msg, true)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'tag already exists' }

      local result, err = ref:create_tag('existing')

      assert.is_nil(result)
      eq(err, { 'tag already exists' })
    end)

    it('should not invalidate cache on error', function()
      ref._tags = { { name = 'v0.9.0', hash = 'old' } }
      mock_execute_err = { 'error' }

      ref:create_tag('bad')

      eq(#ref._tags, 1)
    end)
  end)

  describe('delete_tag()', function()
    it('should error when name is nil', function()
      local result, err = ref:delete_tag(nil)

      assert.is_nil(result)
      eq(err, { 'tag name is required' })
    end)

    it('should delete tag and return true', function()
      mock_execute_result = {}
      mock_execute_err = nil

      local result, err = ref:delete_tag('v1.0.0')

      assert.is_nil(err)
      eq(result, true)
    end)

    it('should invalidate tags cache', function()
      ref._tags = { { name = 'v1.0.0', hash = 'abc' } }
      mock_execute_result = {}
      mock_execute_err = nil

      ref:delete_tag('v1.0.0')

      assert.is_nil(ref._tags)
    end)

    it('should propagate errors', function()
      mock_execute_err = { 'tag not found' }

      local result, err = ref:delete_tag('nonexistent')

      assert.is_nil(result)
      eq(err, { 'tag not found' })
    end)

    it('should not invalidate cache on error', function()
      ref._tags = { { name = 'v1.0.0', hash = 'abc' } }
      mock_execute_err = { 'error' }

      ref:delete_tag('bad')

      eq(#ref._tags, 1)
    end)
  end)

  describe('reset_cache()', function()
    it('should clear all caches', function()
      ref._branches = { { name = 'main', hash = 'abc' } }
      ref._tags = { { name = 'v1.0.0', hash = 'def' } }
      ref._current = { name = 'main', hash = 'abc', is_detached = false }

      ref:reset_cache()

      assert.is_nil(ref._branches)
      assert.is_nil(ref._tags)
      assert.is_nil(ref._current)
    end)

    it('should be safe to call when caches are already nil', function()
      ref._branches = nil
      ref._tags = nil
      ref._current = nil

      ref:reset_cache()

      assert.is_nil(ref._branches)
      assert.is_nil(ref._tags)
      assert.is_nil(ref._current)
    end)

    it('should allow fresh data to be fetched after reset', function()
      -- Pre-populate caches
      ref._current = { name = 'old', hash = 'old_hash', is_detached = false }
      ref._tags = { { name = 'old_tag', hash = 'old' } }

      ref:reset_cache()

      -- Now set up new mock data
      mock_execute_result = { 'v2.0.0\x1Fnew_hash' }
      mock_execute_err = nil

      local tags, err = ref:tags()

      assert.is_nil(err)
      eq(#tags, 1)
      eq(tags[1].name, 'v2.0.0')
    end)
  end)
end)

-- Restore real modules after all tests
package.loaded['vgit.git.GitQueryBuilder'] = real_git_query_builder
package.loaded['vgit.git.git_repo'] = real_git_repo
package.loaded['vgit.git.GitRef'] = nil
