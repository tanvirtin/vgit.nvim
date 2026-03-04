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

      eq('Live Gutter', instance._name)
    end)

    it('should initialize debounced fetch function and cleanup', function()
      local instance = LiveGutter()

      assert.is_function(instance._fetch_debounced)
      assert.is_function(instance._fetch_debounced_cleanup)
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

  describe('toggle', function()
    it('should call fetch when enabled', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_for_each = git_buffer_store.for_each

      local instance = LiveGutter()
      local fetch_called = false
      instance.fetch = function() fetch_called = true end
      instance.is_enabled = function() return true end

      git_buffer_store.for_each = function(callback)
        callback({ render_signs = function() end })
      end

      instance:toggle()
      assert.is_true(fetch_called)

      git_buffer_store.for_each = original_for_each
    end)

    it('should call reset_signs when disabled', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_for_each = git_buffer_store.for_each

      local instance = LiveGutter()
      local reset_called = false
      instance.is_enabled = function() return false end

      git_buffer_store.for_each = function(callback)
        callback({
          reset_signs = function() reset_called = true end,
          render_signs = function() end,
        })
      end

      instance:toggle()
      assert.is_true(reset_called)

      git_buffer_store.for_each = original_for_each
    end)

    it('should call render_signs on each buffer regardless of enabled state', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_for_each = git_buffer_store.for_each

      local instance = LiveGutter()
      local render_count = 0
      instance.is_enabled = function() return false end

      git_buffer_store.for_each = function(callback)
        for _ = 1, 3 do
          callback({
            reset_signs = function() end,
            render_signs = function() render_count = render_count + 1 end,
          })
        end
      end

      instance:toggle()
      eq(3, render_count)

      git_buffer_store.for_each = original_for_each
    end)
  end)

  describe('register_events', function()
    it('should subscribe to buffer store events', function()
      local git_buffer_store = require('vgit.git.git_buffer_store')
      local original_on = git_buffer_store.on
      local on_calls = {}

      local mock_chain = {}
      mock_chain.on = function(events, handler)
        table.insert(on_calls, { events = events })
        return mock_chain
      end

      git_buffer_store.on = mock_chain.on

      local instance = LiveGutter()
      instance:register_events()

      eq(4, #on_calls)
      eq({ 'attach', 'reload' }, on_calls[1].events)
      eq({ 'change' }, on_calls[2].events)
      eq('sync', on_calls[3].events)
      eq('detach', on_calls[4].events)

      git_buffer_store.on = original_on
    end)
  end)

  describe('cleanup', function()
    it('should call _fetch_debounced_cleanup if it exists', function()
      local called = false

      local instance = LiveGutter()
      instance._fetch_debounced_cleanup = function()
        called = true
      end
      instance:cleanup()

      assert.is_true(called)
    end)

    it('should handle nil _fetch_debounced_cleanup', function()
      local instance = LiveGutter()
      instance._fetch_debounced_cleanup = nil

      instance:cleanup()
    end)
  end)
end)
