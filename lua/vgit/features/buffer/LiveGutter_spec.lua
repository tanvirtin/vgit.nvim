local eq = assert.are.same

describe('LiveGutter:', function()
  local LiveGutter
  local live_gutter_setting

  before_each(function()
    LiveGutter = require('vgit.features.buffer.LiveGutter')
    live_gutter_setting = require('vgit.settings.live_gutter')
  end)

  describe('constructor', function()
    it('should set name to Live Gutter', function()
      local instance = LiveGutter()

      eq('Live Gutter', instance.name)
    end)

    it('should initialize empty debounce_cleanups', function()
      local instance = LiveGutter()

      assert.is_table(instance.debounce_cleanups)
      eq(0, #instance.debounce_cleanups)
    end)
  end)

  describe('is_enabled', function()
    it('should return true when setting is enabled', function()
      local original = live_gutter_setting.get
      live_gutter_setting.get = function(self, key)
        if key == 'enabled' then return true end
        return original(self, key)
      end

      local instance = LiveGutter()
      assert.is_true(instance:is_enabled())

      live_gutter_setting.get = original
    end)

    it('should return false when setting is disabled', function()
      local original = live_gutter_setting.get
      live_gutter_setting.get = function(self, key)
        if key == 'enabled' then return false end
        return original(self, key)
      end

      local instance = LiveGutter()
      assert.is_false(instance:is_enabled())

      live_gutter_setting.get = original
    end)
  end)

  describe('cleanup', function()
    it('should call _fetch_debounced_cleanup if it exists', function()
      local called = false

      local instance = LiveGutter()
      instance._fetch_debounced_cleanup = function() called = true end
      instance:cleanup()

      assert.is_true(called)
    end)

    it('should handle nil _fetch_debounced_cleanup', function()
      local instance = LiveGutter()
      instance._fetch_debounced_cleanup = nil

      -- Should not error
      instance:cleanup()
    end)
  end)
end)
