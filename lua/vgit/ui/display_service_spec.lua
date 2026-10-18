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
    it('should be idempotent — calling twice does not double-register handlers', function()
      display_service.register_events()
      display_service.register_events()

      local ok = pcall(event.emit, 'VGitDirChanged', {})
      assert.is_true(ok)
      assert.is_nil(display_service.get_active_view())
    end)
  end)

  describe('reset', function()
    it('should clear active_view', function()
      display_service.reset()
      assert.is_nil(display_service.get_active_view())
    end)

    it('should allow re-registering events after reset', function()
      display_service.register_events()
      display_service.reset()

      assert.has_no.errors(function()
        display_service.register_events()
      end)
    end)
  end)

  describe('toggle_diff_preference', function()
    it('should not error when toggled', function()
      assert.has_no.errors(function()
        display_service.toggle_diff_preference()
      end)
    end)
  end)

  describe('help', function()
    it('should return false when no active view', function()
      assert.is_false(display_service.help())
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
      display_service.register_events()

      local ok = pcall(function()
        event.emit('VGitDirChanged', {})
        event.emit('VGitDirChanged', {})
      end)

      assert.is_true(ok)
      assert.is_nil(display_service.get_active_view())
    end)
  end)

  describe('working tree refresh', function()
    local function count_autocmds(name)
      return #vim.api.nvim_get_autocmds({ event = name })
    end

    it('should register FocusGained and BufWritePost handlers', function()
      local focus_before = count_autocmds('FocusGained')
      local write_before = count_autocmds('BufWritePost')

      display_service.register_events()

      eq(focus_before + 1, count_autocmds('FocusGained'))
      eq(write_before + 1, count_autocmds('BufWritePost'))
    end)

    it('should remove the handlers on reset', function()
      local focus_before = count_autocmds('FocusGained')

      display_service.register_events()
      display_service.reset()

      eq(focus_before, count_autocmds('FocusGained'))
    end)

    it('should not register the handlers twice', function()
      local focus_before = count_autocmds('FocusGained')

      display_service.register_events()
      display_service.register_events()

      eq(focus_before + 1, count_autocmds('FocusGained'))
    end)

    it('should not error when focus returns with no active view', function()
      display_service.register_events()

      local ok = pcall(vim.api.nvim_exec_autocmds, 'FocusGained', {})

      assert.is_true(ok)
    end)
  end)
end)
