local eq = assert.are.same

describe('LiveBlame:', function()
  local LiveBlame

  before_each(function()
    LiveBlame = require('vgit.features.buffer.LiveBlame')
  end)

  describe('constructor', function()
    it('should set name to Live Blame', function()
      local instance = LiveBlame()

      eq('Live Blame', instance.name)
    end)

    it('should initialize empty debounce_cleanups', function()
      local instance = LiveBlame()

      assert.is_table(instance.debounce_cleanups)
      eq(0, #instance.debounce_cleanups)
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
          clear_blames = function(self) table.insert(cleared, true) end,
        }
        callback(mock_buffer)
      end

      instance:reset()

      eq(1, #cleared)

      git_buffer_store.for_each = original_for_each
    end)
  end)

  describe('cleanup', function()
    it('should call each cleanup function and reset list', function()
      local instance = LiveBlame()
      local called = { false, false }

      instance.debounce_cleanups = {
        function() called[1] = true end,
        function() called[2] = true end,
      }

      instance:cleanup()

      assert.is_true(called[1])
      assert.is_true(called[2])
      eq(0, #instance.debounce_cleanups)
    end)

    it('should handle empty debounce_cleanups', function()
      local instance = LiveBlame()

      instance:cleanup()

      eq(0, #instance.debounce_cleanups)
    end)
  end)
end)
