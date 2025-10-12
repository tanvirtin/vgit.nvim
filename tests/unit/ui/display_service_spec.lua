local display_service = require('vgit.ui.display_service')
local window_manager = require('vgit.ui.window_manager')

describe('display_service:', function()
  it('should be an alias to window_manager', function()
    assert.are.equal(window_manager, display_service)
  end)

  it('should expose create method', function()
    assert.is_function(display_service.create)
  end)

  it('should expose destroy_active_screen method', function()
    assert.is_function(display_service.destroy_active_screen)
  end)

  it('should expose has_active_screen method', function()
    assert.is_function(display_service.has_active_screen)
  end)

  it('should expose dispatch_action method', function()
    assert.is_function(display_service.dispatch_action)
  end)

  it('should expose toggle_diff_preference method', function()
    assert.is_function(display_service.toggle_diff_preference)
  end)

  it('should expose help method', function()
    assert.is_function(display_service.help)
  end)

  it('should expose screens registry', function()
    assert.is_table(display_service.screens)
  end)

  it('should expose is_screen_registered method', function()
    assert.is_function(display_service.is_screen_registered)
  end)
end)
