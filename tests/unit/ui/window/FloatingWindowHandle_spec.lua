local Buffer = require('vgit.core.Buffer')
local FloatingWindowHandle = require('vgit.ui.window.FloatingWindowHandle')

describe('FloatingWindowHandle:', function()
  local buffer

  before_each(function()
    buffer = Buffer():create(false, true)
  end)

  after_each(function()
    if buffer and buffer:is_valid() then buffer:delete() end
  end)

  describe('constructor', function()
    it('should create a new instance without a window', function()
      local handle = FloatingWindowHandle()
      assert.is_nil(handle.window)
    end)

    it('should accept an existing window', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is_not_nil(handle.window)
    end)
  end)

  describe('open', function()
    it('should open a floating window', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is_true(handle:is_valid())
    end)

    it('should support cursor-relative positioning (lens mode)', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'cursor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is_true(handle:is_valid())
    end)
  end)

  describe('close', function()
    it('should close the window', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      handle:close()
      assert.is_false(handle:is_valid())
    end)

    it('should not error when window is nil', function()
      local handle = FloatingWindowHandle()
      handle:close()
    end)
  end)

  describe('is_valid', function()
    it('should return false when window is nil', function()
      local handle = FloatingWindowHandle()
      assert.is_false(handle:is_valid())
    end)

    it('should return true for valid window', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is_true(handle:is_valid())
    end)
  end)

  describe('dimensions', function()
    it('should get and set width', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is.equal(10, handle:get_width())
      handle:set_width(20)
      assert.is.equal(20, handle:get_width())
    end)

    it('should get and set height', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is.equal(10, handle:get_height())
      handle:set_height(20)
      assert.is.equal(20, handle:get_height())
    end)

    it('should return 0 for width when window is nil', function()
      local handle = FloatingWindowHandle()
      assert.is.equal(0, handle:get_width())
    end)

    it('should return 0 for height when window is nil', function()
      local handle = FloatingWindowHandle()
      assert.is.equal(0, handle:get_height())
    end)
  end)

  describe('cursor operations', function()
    it('should get cursor position', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      local cursor = handle:get_cursor()
      assert.is.same({ 1, 0 }, cursor)
    end)

    it('should get line number', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      local lnum = handle:get_lnum()
      assert.is.equal(1, lnum)
    end)

    it('should return defaults when window is nil', function()
      local handle = FloatingWindowHandle()
      assert.is.same({ 1, 1 }, handle:get_cursor())
      assert.is.equal(1, handle:get_lnum())
    end)

    it('should set cursor position', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      buffer:set_lines({ 'line1', 'line2', 'line3' })
      handle:set_cursor({ 2, 0 })
      local cursor = handle:get_cursor()
      assert.is.equal(2, cursor[1])
    end)

    it('should set line number', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      buffer:set_lines({ 'line1', 'line2', 'line3' })
      handle:set_lnum(3)
      assert.is.equal(3, handle:get_lnum())
    end)
  end)

  describe('window options', function()
    it('should set window options', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      handle:set_option('wrap', true)
      -- Just verify no errors occur
      assert.is_true(handle:is_valid())
    end)

    it('should assign multiple options', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      handle:assign_options({
        wrap = true,
        number = false,
      })
      assert.is_true(handle:is_valid())
    end)
  end)

  describe('focus', function()
    it('should focus the window', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      handle:focus()
      assert.is_true(handle:is_focused())
    end)

    it('should not error when window is nil', function()
      local handle = FloatingWindowHandle()
      handle:focus()
    end)
  end)

  describe('position', function()
    it('should get position', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 5,
        col = 10,
      })
      local pos = handle:get_position()
      assert.is.equal(5, pos[1])
      assert.is.equal(10, pos[2])
    end)

    it('should return default position when window is nil', function()
      local handle = FloatingWindowHandle()
      local pos = handle:get_position()
      assert.is.same({ row = 0, col = 0 }, pos)
    end)
  end)

  describe('comparison', function()
    it('should compare handles correctly', function()
      local handle1 = FloatingWindowHandle()
      local handle2 = FloatingWindowHandle()

      handle1:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      local buffer2 = Buffer():create(false, true)
      handle2:open(buffer2, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })

      assert.is_false(handle1:is_same(handle2))
      assert.is_true(handle1:is_same(handle1))

      if buffer2 and buffer2:is_valid() then buffer2:delete() end
    end)

    it('should return false when comparing with nil windows', function()
      local handle1 = FloatingWindowHandle()
      local handle2 = FloatingWindowHandle()
      assert.is_false(handle1:is_same(handle2))
    end)

    it('should return false when comparing with nil handle', function()
      local handle1 = FloatingWindowHandle()
      handle1:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      assert.is_false(handle1:is_same(nil))
    end)
  end)

  describe('get_window', function()
    it('should return the window instance', function()
      local handle = FloatingWindowHandle()
      handle:open(buffer, {
        relative = 'editor',
        width = 10,
        height = 10,
        row = 0,
        col = 0,
      })
      local window = handle:get_window()
      assert.is_not_nil(window)
      assert.is_not_nil(window.win_id)
    end)

    it('should return nil when no window exists', function()
      local handle = FloatingWindowHandle()
      local window = handle:get_window()
      assert.is_nil(window)
    end)
  end)
end)
