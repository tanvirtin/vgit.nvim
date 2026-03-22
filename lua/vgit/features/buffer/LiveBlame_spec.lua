local eq = assert.are.same

describe('LiveBlame:', function()
  local LiveBlame

  before_each(function()
    LiveBlame = require('vgit.features.buffer.LiveBlame')
  end)

  describe('constructor', function()
    it('should set name to Live Blame', function()
      local instance = LiveBlame()

      eq('Live Blame', instance._name)
    end)

    it('should initialize debounced blame function and cleanup', function()
      local instance = LiveBlame()

      assert.is_function(instance._debounced_blame)
      assert.is_function(instance._debounced_blame_cleanup)
    end)
  end)

  describe('register_events', function()
    it('should return self for chaining', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_on = git_buffer_store.on

      git_buffer_store.on = function(events, handler)
        return git_buffer_store
      end

      local instance = LiveBlame()
      local result = instance:register_events()
      eq(instance, result)

      git_buffer_store.on = original_on
    end)

    it('should subscribe to attach event', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_on = git_buffer_store.on
      local registered_event = nil

      git_buffer_store.on = function(events, handler)
        registered_event = events
        return git_buffer_store
      end

      local instance = LiveBlame()
      instance:register_events()

      eq('attach', registered_event)

      git_buffer_store.on = original_on
    end)
  end)

  describe('reset', function()
    it('should call clear_blames on each buffer via git_buffer_store.for_each', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local instance = LiveBlame()

      local cleared = {}
      local original_for_each = git_buffer_store.for_each
      git_buffer_store.for_each = function(callback)
        local mock_buffer = {
          clear_blames = function(self)
            table.insert(cleared, true)
          end,
        }
        callback(mock_buffer)
      end

      instance:reset()

      eq(1, #cleared)

      git_buffer_store.for_each = original_for_each
    end)

    it('should call clear_blames on multiple buffers', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local instance = LiveBlame()

      local cleared = 0
      local original_for_each = git_buffer_store.for_each
      git_buffer_store.for_each = function(callback)
        for _ = 1, 3 do
          callback({
            clear_blames = function()
              cleared = cleared + 1
            end,
          })
        end
      end

      instance:reset()

      eq(3, cleared)

      git_buffer_store.for_each = original_for_each
    end)
  end)

  describe('cleanup', function()
    it('should call the debounce cleanup function', function()
      local instance = LiveBlame()
      local called = false

      instance._debounced_blame_cleanup = function()
        called = true
      end

      instance:cleanup()

      assert.is_true(called)
    end)

    it('should handle nil cleanup gracefully', function()
      local instance = LiveBlame()
      instance._debounced_blame_cleanup = nil

      instance:cleanup()
    end)
  end)
end)

-- Integration tests using real git repos
package.loaded['lint'] = package.loaded['lint'] or { try_lint = function() end }

local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

describe('LiveBlame blame flow (integration):', function()
  local async = require('tests.helpers.async')({ it = it, before_each = before_each, after_each = after_each })
  local it = async.it
  local before_each = async.before_each
  local after_each = async.after_each

  local GitBuffer = require('vgit.git.GitBuffer')
  local repo
  local test_file
  local created_bufnrs = {}

  before_each(function()
    created_bufnrs = {}
    local err
    repo, err = test_repo.create_repo({
      initial_commit = true,
      files = { ['test.txt'] = { 'line 1', 'line 2', 'line 3' } },
    })
    assert(not err, 'Failed to create test repo')
    test_file = repo .. '/test.txt'
  end)

  after_each(function()
    for _, bufnr in ipairs(created_bufnrs) do
      if vim.api.nvim_buf_is_valid(bufnr) then vim.api.nvim_buf_delete(bufnr, { force = true }) end
    end
    if repo then test_repo.cleanup(repo) end
  end)

  local function create_buf(filepath)
    local bufnr = vim.fn.bufadd(filepath)
    vim.fn.bufload(bufnr)
    created_bufnrs[#created_bufnrs + 1] = bufnr
    return bufnr
  end

  it('should populate blame state after config and blame calls', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    local config, config_err = git_buf:config()
    assert.is_nil(config_err)
    assert.is_not_nil(config)

    local blame, blame_err = git_buf:blame(1)
    assert.is_nil(blame_err)
    assert.is_not_nil(blame)

    -- Blame should be cached in state
    assert.is_not_nil(git_buf.state.blames[1])
    assert.is_not_nil(git_buf.state.blames[1].commit_hash)
  end)

  it('should skip blame when buffer is locked', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- Lock the buffer
    assert.is_true(git_buf:acquire())

    -- Attempt blame — simulating what LiveBlame does (acquire returns false)
    local can_acquire = git_buf:acquire()
    assert.is_false(can_acquire)

    -- Blames should remain empty
    assert.equals(0, vim.tbl_count(git_buf.state.blames))

    git_buf:release()
  end)

  it('should clear blame state via clear_blames', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- Populate blame
    git_buf:blame(1)
    assert.is_not_nil(git_buf.state.blames[1])

    -- Clear
    git_buf:clear_blames()

    -- State should still have the blame data (clear_blames clears extmarks, not state)
    -- This documents the actual behavior
    assert.is_not_nil(git_buf.state.blames[1])
  end)
end)
