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
