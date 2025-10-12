local window_manager = require('vgit.ui.window_manager')

describe('window_manager:', function()
  before_each(function()
    window_manager.active_screen = nil
    window_manager.stack = {}
  end)

  describe('has_active_screen', function()
    it('should return false when no active screen', function()
      assert.is_false(window_manager.has_active_screen())
    end)

    it('should return true when active screen exists', function()
      window_manager.active_screen = { name = 'test_screen' }
      assert.is_true(window_manager.has_active_screen())
    end)
  end)

  describe('get_active_screen', function()
    it('should return nil when no active screen', function()
      assert.is_nil(window_manager.get_active_screen())
    end)

    it('should return active screen when it exists', function()
      local test_screen = { name = 'test_screen' }
      window_manager.active_screen = test_screen
      assert.are.equal(test_screen, window_manager.get_active_screen())
    end)
  end)

  describe('get_stack_depth', function()
    it('should return 0 when stack is empty', function()
      assert.are.equal(0, window_manager.get_stack_depth())
    end)

    it('should return correct depth when screens are stacked', function()
      window_manager.stack = {
        { name = 'screen1' },
        { name = 'screen2' },
        { name = 'screen3' },
      }
      assert.are.equal(3, window_manager.get_stack_depth())
    end)
  end)

  describe('is_screen_registered', function()
    it('should return true for registered screens', function()
      assert.is_true(window_manager.is_screen_registered('diff_screen'))
      assert.is_true(window_manager.is_screen_registered('project_diff_screen'))
    end)

    it('should return false for unregistered screens', function()
      assert.is_false(window_manager.is_screen_registered('nonexistent_screen'))
    end)
  end)

  describe('clear_stack', function()
    it('should clear the stack', function()
      window_manager.stack = {
        { name = 'screen1', scene = { destroy = function() end } },
        { name = 'screen2', scene = { destroy = function() end } },
      }

      window_manager.clear_stack()
      assert.are.equal(0, window_manager.get_stack_depth())
    end)

    it('should destroy all screens in stack', function()
      local destroy_count = 0
      window_manager.stack = {
        {
          name = 'screen1',
          destroy = function()
            destroy_count = destroy_count + 1
          end,
        },
        {
          name = 'screen2',
          destroy = function()
            destroy_count = destroy_count + 1
          end,
        },
      }

      window_manager.clear_stack()
      assert.are.equal(2, destroy_count)
    end)
  end)

  describe('has_action', function()
    it('should return false when no active screen', function()
      assert.is_false(window_manager.has_action('some_action'))
    end)

    it('should return false when action does not exist', function()
      window_manager.active_screen = { name = 'test_screen' }
      assert.is_false(window_manager.has_action('nonexistent_action'))
    end)

    it('should return true when action exists', function()
      window_manager.active_screen = {
        name = 'test_screen',
        hunk_up = function() end,
      }
      assert.is_true(window_manager.has_action('hunk_up'))
    end)
  end)
end)
