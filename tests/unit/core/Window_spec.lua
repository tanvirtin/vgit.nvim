local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

describe('Window:', function()
  local buffer, win

  local function create_test_buffer()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {'Line 1', 'Line 2', 'Line 3'})
    return Buffer(buf)
  end

  local default_float_opts = {
    relative = 'editor',
    width = 20,
    height = 10,
    row = 5,
    col = 5
  }

  before_each(function()
    buffer = create_test_buffer()
  end)

  after_each(function()
    if win and win.win_id and vim.api.nvim_win_is_valid(win.win_id) then
      win:close()
    end
    if buffer and buffer.bufnr and vim.api.nvim_buf_is_valid(buffer.bufnr) then
      vim.api.nvim_buf_delete(buffer.bufnr, {force = true})
    end
  end)

  describe('constructor', function()
    it('should create a new Window instance with given win_id', function()
      win = Window(vim.api.nvim_get_current_win())

      assert(win:is(Window))
      assert.are.equal(vim.api.nvim_get_current_win(), win.win_id)
    end)

    it('should use current window if win_id is 0', function()
      local current_win = vim.api.nvim_get_current_win()
      win = Window(0)

      assert.are.equal(current_win, win.win_id)
    end)

    it('should throw an error if win_id is not a number', function()
      assert.has_error(function() Window('not a number') end)
    end)
  end)

  describe('open', function()
    it('should open a new window with given buffer', function()
      win = Window:open(buffer, default_float_opts)

      assert(win:is(Window))
      assert(vim.api.nvim_win_is_valid(win.win_id))
    end)

    it('should focus the new window if focus option is true', function()
      win = Window:open(buffer, vim.tbl_extend('force', default_float_opts, {focus = true}))

      assert.are.equal(win.win_id, vim.api.nvim_get_current_win())
    end)

    it('should throw an error if buffer is not provided', function()
      assert.has_error(function() Window:open() end, 'buffer is required')
    end)
  end)

  describe('get_cursor', function()
    it('should return cursor position', function()
      win = Window:open(buffer, default_float_opts)
      local cursor = win:get_cursor()

      assert.is_table(cursor)
      assert.are.equal(2, #cursor)
    end)

    it('should return {1, 1} if get_cursor fails', function()
      win = Window(-1)  -- Invalid window

      local cursor = win:get_cursor()
      assert.are.same({1, 1}, cursor)
    end)
  end)

  describe('get_lnum', function()
    it('should return the current line number', function()
      win = Window:open(buffer, default_float_opts)
      win:set_cursor({2, 0})

      assert.are.equal(2, win:get_lnum())
    end)
  end)

  describe('get_position', function()
    it('should return the window position', function()
      win = Window:open(buffer, default_float_opts)
      local position = win:get_position()

      assert.is_table(position)
      assert.are.equal(2, #position)
    end)
  end)

  describe('get_height', function()
    it('should return the window height', function()
      win = Window:open(buffer, default_float_opts)
      local height = win:get_height()

      assert.is_number(height)
      assert.are.equal(default_float_opts.height, height)
    end)
  end)

  describe('get_width', function()
    it('should return the window width', function()
      win = Window:open(buffer, default_float_opts)
      local width = win:get_width()

      assert.is_number(width)
      assert.are.equal(default_float_opts.width, width)
    end)
  end)

  describe('set_cursor', function()
    it('should set cursor position', function()
      win = Window:open(buffer, default_float_opts)
      win:set_cursor({2, 0})
      local cursor = win:get_cursor()

      assert.are.same({2, 0}, cursor)
    end)
  end)

  describe('set_lnum', function()
    it('should set the line number while maintaining column position', function()
      win = Window:open(buffer, default_float_opts)
      win:set_cursor({1, 2})
      win:set_lnum(2)

      assert.are.same({2, 2}, win:get_cursor())
    end)
  end)

  describe('set_option', function()
    it('should set a window option', function()
      win = Window:open(buffer, default_float_opts)
      win:set_option('wrap', false)

      assert.is_false(vim.api.nvim_win_get_option(win.win_id, 'wrap'))
    end)
  end)

  describe('set_height', function()
    it('should set the window height', function()
      win = Window:open(buffer, default_float_opts)
      win:set_height(15)

      assert.are.equal(15, win:get_height())
    end)
  end)

  describe('set_width', function()
    it('should set the window width', function()
      win = Window:open(buffer, default_float_opts)
      win:set_width(25)

      assert.are.equal(25, win:get_width())
    end)
  end)

  describe('set_win_plot and get_win_plot', function()
    it('should set and get window configuration', function()
      win = Window:open(buffer, default_float_opts)
      local config = {relative = 'editor', row = 6, col = 11, width = 31, height = 16}
      win:set_win_plot(config)
      local new_config = win:get_win_plot()

      assert.are.same(6, new_config.row)
      assert.are.same(11, new_config.col)
      assert.are.same(31, new_config.width)
      assert.are.same(16, new_config.height)
    end)
  end)

  describe('assign_options', function()
    it('should set multiple window options', function()
      win = Window:open(buffer, default_float_opts)
      win:assign_options({wrap = false, number = true})

      assert.is_false(vim.api.nvim_win_get_option(win.win_id, 'wrap'))
      assert.is_true(vim.api.nvim_win_get_option(win.win_id, 'number'))
    end)
  end)

  describe('is_valid', function()
    it('should return true for valid window', function()
      win = Window:open(buffer, default_float_opts)

      assert.is_true(win:is_valid())
    end)

    it('should return false for invalid window', function()
      win = Window(-1)

      assert.is_false(win:is_valid())
    end)
  end)

  describe('close', function()
    it('should close the window', function()
      win = Window:open(buffer, default_float_opts)
      local win_id = win.win_id
      win:close()

      assert.is_false(vim.api.nvim_win_is_valid(win_id))
    end)
  end)

  describe('is_focused', function()
    it('should return true if window is focused', function()
      win = Window:open(buffer, vim.tbl_extend('force', default_float_opts, {focus = true}))

      assert.is_true(win:is_focused())
    end)

    it('should return false if window is not focused', function()
      win = Window:open(buffer, vim.tbl_extend('force', default_float_opts, {focus = false}))

      assert.is_false(win:is_focused())
    end)
  end)

  describe('focus', function()
    it('should focus the window', function()
      win = Window:open(buffer, vim.tbl_extend('force', default_float_opts, {focus = false}))
      win:focus()

      assert.is_true(win:is_focused())
    end)
  end)

  describe('is_same', function()
    it('should return true for the same window', function()
      win = Window:open(buffer, default_float_opts)
      local win2 = Window(win.win_id)

      assert.is_true(win:is_same(win2))
    end)

    it('should return false for different windows', function()
      win = Window:open(buffer, default_float_opts)
      local buffer2 = create_test_buffer()
      local win2 = Window:open(buffer2, default_float_opts)

      assert.is_false(win:is_same(win2))
    end)
  end)

  describe('position_cursor', function()
    it('should position cursor at the center by default', function()
      win = Window:open(buffer, default_float_opts)
      win:position_cursor()

      assert.has_no.errors(function() win:get_cursor() end)
    end)

    it('should position cursor at the top when specified', function()
      win = Window:open(buffer, default_float_opts)
      win:position_cursor('top')

      assert.has_no.errors(function() win:get_cursor() end)
    end)
  end)

  describe('call', function()
    it('should execute a callback in the context of the window', function()
      win = Window:open(buffer, default_float_opts)
      local called = false
      win:call(function()
        called = true
        assert.are.equal(win.win_id, vim.api.nvim_get_current_win())
      end)

      assert.is_true(called)
    end)
  end)
end)
