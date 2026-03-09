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
