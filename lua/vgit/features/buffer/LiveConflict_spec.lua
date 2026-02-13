local eq = assert.are.same

describe('LiveConflict:', function()
  local LiveConflict

  before_each(function()
    LiveConflict = require('vgit.features.buffer.LiveConflict')
  end)

  describe('constructor', function()
    it('should set name to Conflict', function()
      local instance = LiveConflict()

      eq('Conflict', instance.name)
    end)

    it('should initialize empty debounce_cleanups', function()
      local instance = LiveConflict()

      assert.is_table(instance.debounce_cleanups)
      eq(0, #instance.debounce_cleanups)
    end)
  end)

  describe('cleanup', function()
    it('should call each cleanup function and reset list', function()
      local instance = LiveConflict()
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
      local instance = LiveConflict()

      -- Should not error
      instance:cleanup()

      eq(0, #instance.debounce_cleanups)
    end)

    it('should reset debounce_cleanups to empty table', function()
      local instance = LiveConflict()
      instance.debounce_cleanups = { function() end }

      instance:cleanup()

      assert.is_table(instance.debounce_cleanups)
      eq(0, #instance.debounce_cleanups)
    end)
  end)
end)
