local eq = assert.are.same

describe('LoadingIndicator:', function()
  local LoadingIndicator

  before_each(function()
    LoadingIndicator = require('vgit.ui.decorators.LoadingIndicator')
  end)

  describe('constructor', function()
    it('should initialize with inactive state', function()
      local indicator = LoadingIndicator()
      assert.is_false(indicator:is_active())
    end)
  end)

  describe('start', function()
    it('should set active state to true', function()
      local indicator = LoadingIndicator()
      indicator:start()
      assert.is_true(indicator:is_active())
      indicator:stop()
    end)

    it('should not restart if already active', function()
      local indicator = LoadingIndicator()
      indicator:start()
      local first_timer = indicator._timer
      indicator:start()
      eq(first_timer, indicator._timer)
      indicator:stop()
    end)
  end)

  describe('stop', function()
    it('should set active state to false', function()
      local indicator = LoadingIndicator()
      indicator:start()
      indicator:stop()
      assert.is_false(indicator:is_active())
    end)

    it('should clean up timer', function()
      local indicator = LoadingIndicator()
      indicator:start()
      indicator:stop()
      assert.is_nil(indicator._timer)
    end)

    it('should be safe to call when not active', function()
      local indicator = LoadingIndicator()
      indicator:stop()
      assert.is_false(indicator:is_active())
    end)

    it('should be safe to call twice', function()
      local indicator = LoadingIndicator()
      indicator:start()
      indicator:stop()
      indicator:stop()
      assert.is_false(indicator:is_active())
      assert.is_nil(indicator._timer)
    end)
  end)

  describe('is_active', function()
    it('should return false initially', function()
      local indicator = LoadingIndicator()
      assert.is_false(indicator:is_active())
    end)

    it('should return true after start', function()
      local indicator = LoadingIndicator()
      indicator:start()
      assert.is_true(indicator:is_active())
      indicator:stop()
    end)

    it('should return false after stop', function()
      local indicator = LoadingIndicator()
      indicator:start()
      indicator:stop()
      assert.is_false(indicator:is_active())
    end)
  end)

  describe('render', function()
    it('should do nothing when element is nil', function()
      local indicator = LoadingIndicator()
      indicator:render(nil)
    end)

    it('should do nothing when element is invalid', function()
      local indicator = LoadingIndicator()
      indicator:render({
        is_valid = function() return false end,
      })
    end)

    it('should set lines on valid element', function()
      local indicator = LoadingIndicator()
      local set_lines_data = nil
      local mock_element = {
        is_valid = function() return true end,
        clear_extmark_highlights = function() end,
        get_height = function() return 10 end,
        get_width = function() return 40 end,
        set_lines = function(_, lines) set_lines_data = lines end,
        place_extmark_highlight = function() end,
      }

      indicator:render(mock_element)

      assert.is_not_nil(set_lines_data)
      assert.is_true(#set_lines_data > 0)
    end)

    it('should center content vertically', function()
      local indicator = LoadingIndicator()
      local set_lines_data = nil
      local mock_element = {
        is_valid = function() return true end,
        clear_extmark_highlights = function() end,
        get_height = function() return 11 end,
        get_width = function() return 40 end,
        set_lines = function(_, lines) set_lines_data = lines end,
        place_extmark_highlight = function() end,
      }

      indicator:render(mock_element)

      -- height=11, vertical_pad = floor((11-1)/2) = 5
      -- 5 empty lines + 1 content line = 6 lines
      eq(6, #set_lines_data)
      for i = 1, 5 do
        eq('', set_lines_data[i])
      end
      -- Last line should contain content (not empty)
      assert.is_true(#set_lines_data[6] > 0)
    end)

    it('should center content horizontally', function()
      local indicator = LoadingIndicator()
      local set_lines_data = nil
      local mock_element = {
        is_valid = function() return true end,
        clear_extmark_highlights = function() end,
        get_height = function() return 1 end,
        get_width = function() return 40 end,
        set_lines = function(_, lines) set_lines_data = lines end,
        place_extmark_highlight = function() end,
      }

      indicator:render(mock_element)

      -- height=1, vertical_pad = 0, so only 1 line
      eq(1, #set_lines_data)
      -- Content line should have leading spaces for centering
      local line = set_lines_data[1]
      local leading_spaces = line:match('^(%s*)')
      assert.is_true(#leading_spaces > 0)
    end)

    it('should place extmark highlight with GitComment', function()
      local indicator = LoadingIndicator()
      local highlight_data = nil
      local mock_element = {
        is_valid = function() return true end,
        clear_extmark_highlights = function() end,
        get_height = function() return 5 end,
        get_width = function() return 40 end,
        set_lines = function() end,
        place_extmark_highlight = function(_, opts) highlight_data = opts end,
      }

      indicator:render(mock_element)

      assert.is_not_nil(highlight_data)
      eq('GitComment', highlight_data.hl)
      -- row should be the vertical padding
      eq(2, highlight_data.row) -- floor((5-1)/2) = 2
      assert.is_not_nil(highlight_data.col_range)
      eq(0, highlight_data.col_range.from)
    end)

    it('should clear extmark highlights before rendering', function()
      local indicator = LoadingIndicator()
      local clear_called = false
      local mock_element = {
        is_valid = function() return true end,
        clear_extmark_highlights = function() clear_called = true end,
        get_height = function() return 5 end,
        get_width = function() return 40 end,
        set_lines = function() end,
        place_extmark_highlight = function() end,
      }

      indicator:render(mock_element)

      assert.is_true(clear_called)
    end)
  end)
end)
