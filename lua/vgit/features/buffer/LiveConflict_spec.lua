local eq = assert.are.same

describe('LiveConflict:', function()
  local LiveConflict

  before_each(function()
    LiveConflict = require('vgit.features.buffer.LiveConflict')
  end)

  describe('constructor', function()
    it('should set name to Conflict', function()
      local instance = LiveConflict()

      eq('Conflict', instance._name)
    end)

    it('should initialize debounced conflicts function and cleanup', function()
      local instance = LiveConflict()

      assert.is_function(instance._debounced_conflicts)
      assert.is_function(instance._debounced_conflicts_cleanup)
    end)
  end)

  describe('register_events', function()
    it('should return self for chaining', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_on = git_buffer_store.on
      git_buffer_store.on = function()
        return git_buffer_store
      end

      local instance = LiveConflict()
      local result = instance:register_events()
      eq(instance, result)

      git_buffer_store.on = original_on
    end)

    it('should subscribe to attach, reload, change, sync events', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_on = git_buffer_store.on
      local registered_events = nil

      git_buffer_store.on = function(events, handler)
        registered_events = events
        return git_buffer_store
      end

      local instance = LiveConflict()
      instance:register_events()

      eq({ 'attach', 'reload', 'change', 'sync' }, registered_events)

      git_buffer_store.on = original_on
    end)
  end)

  describe('cleanup', function()
    it('should call the debounce cleanup function', function()
      local instance = LiveConflict()
      local called = false

      instance._debounced_conflicts_cleanup = function()
        called = true
      end

      instance:cleanup()

      assert.is_true(called)
    end)

    it('should handle nil cleanup gracefully', function()
      local instance = LiveConflict()
      instance._debounced_conflicts_cleanup = nil

      instance:cleanup()
    end)
  end)
end)

-- Integration tests using real git repos
package.loaded['lint'] = package.loaded['lint'] or { try_lint = function() end }

local test_repo = require('tests.helpers.test_repo')
test_repo.use_driver('raw')

describe('LiveConflict conflict flow (integration):', function()
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

  it('should return empty conflicts on non-conflict file', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    local conflicts = git_buf:conflicts()

    assert.is_table(conflicts)
    assert.equals(0, #conflicts)
  end)

  it('should clear stale conflict state', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- Manually set stale conflict state
    git_buf.state.conflicts = { { current = { top = 1, bot = 2 }, incoming = { top = 3, bot = 4 } } }
    assert.equals(1, #git_buf.state.conflicts)

    -- Calling conflicts() on a non-conflict file should clear stale state
    local conflicts = git_buf:conflicts()

    assert.is_table(conflicts)
    assert.equals(0, #conflicts)
    assert.equals(0, #git_buf.state.conflicts)
  end)

  it('should render conflicts without error on real buffer', function()
    local bufnr = create_buf(test_file)
    local git_buf = GitBuffer(bufnr)
    git_buf:sync()

    -- No conflicts, but render should still succeed
    git_buf:conflicts()
    local result = git_buf:render_conflicts()

    assert.equals(git_buf, result)
  end)
end)
