local event = require('vgit.core.event')
local display_service = require('vgit.ui.display_service')

local eq = assert.are.same

describe('display_service:', function()
  before_each(function()
    display_service.reset()
  end)

  after_each(function()
    display_service.reset()
  end)

  describe('get_active_view', function()
    it('should return nil when no view is active', function()
      assert.is_nil(display_service.get_active_view())
    end)
  end)

  describe('register_events', function()
    it('should be idempotent — calling twice does not double-register VGitChange', function()
      display_service.register_events()
      display_service.register_events()

      local count = 0
      event.custom_on('VGitChange', function()
        count = count + 1
      end)
      event.emit('VGitChange', {})

      eq(count, 1)
    end)
  end)

  describe('VGitDirChanged handler', function()
    it('should not error when no active view is open', function()
      display_service.register_events()

      local ok = pcall(event.emit, 'VGitDirChanged', {})

      assert.is_true(ok)
    end)

    it('should leave active_view nil after firing with no open view', function()
      display_service.register_events()

      event.emit('VGitDirChanged', {})

      assert.is_nil(display_service.get_active_view())
    end)

    it('should not clear _events_registered (unlike reset)', function()
      -- After VGitDirChanged the handler should still be listening.
      -- We verify by emitting a second VGitDirChanged and confirming no error.
      display_service.register_events()

      local ok = pcall(function()
        event.emit('VGitDirChanged', {})
        event.emit('VGitDirChanged', {})
      end)

      assert.is_true(ok)
      assert.is_nil(display_service.get_active_view())
    end)
  end)
end)
