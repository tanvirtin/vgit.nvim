local Element = require('vgit.ui.elements.Element')

local eq = assert.are.same

-- Helper to create an element with valid floating window config
local function create_element(overrides)
  overrides = overrides or {}
  return Element(vim.tbl_deep_extend('force', {
    win_plot = {
      relative = 'editor',
      width = 40,
      height = 10,
      row = 1,
      col = 1,
      style = 'minimal',
    },
    buf_options = {
      modifiable = false,
      buflisted = false,
      bufhidden = 'wipe',
    },
    win_options = {
      wrap = false,
      number = false,
      cursorline = false,
    },
  }, overrides))
end

describe('Element:', function()
  after_each(function()
    -- Clean up all buffers/windows created during tests
    pcall(function()
      for _, win_id in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win_id)
        if config.relative and config.relative ~= '' then
          pcall(vim.api.nvim_win_close, win_id, true)
        end
      end
    end)
    pcall(function()
      for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) then
          pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
        end
      end
    end)
  end)

  describe('constructor', function()
    it('should store props', function()
      local el = create_element()
      assert.is_not_nil(el.props)
    end)

    it('should start unmounted', function()
      local el = create_element()
      assert.is_false(el._mounted)
    end)

    it('should have nil buffer and window before mount', function()
      local el = create_element()
      assert.is_nil(el._buffer)
      assert.is_nil(el._window)
    end)

    it('should default props to empty table', function()
      local el = Element()
      eq({}, el.props)
    end)
  end)

  describe('mount', function()
    it('should set mounted to true', function()
      local el = create_element()
      el:mount()
      assert.is_true(el._mounted)
    end)

    it('should create buffer and window', function()
      local el = create_element()
      el:mount()
      assert.is_not_nil(el._buffer)
      assert.is_not_nil(el._window)
    end)

    it('should return self for chaining', function()
      local el = create_element()
      local result = el:mount()
      assert.are.equal(el, result)
    end)

    it('should be idempotent', function()
      local el = create_element()
      el:mount()
      local buf = el._buffer
      local win = el._window
      el:mount()
      assert.are.equal(buf, el._buffer)
      assert.are.equal(win, el._window)
    end)

    it('should apply deferred lines on mount', function()
      local el = create_element()
      -- Set lines before mount - they should be stored in _lines
      el._lines = { 'hello', 'world' }
      el:mount()
      local lines = el:get_lines()
      eq({ 'hello', 'world' }, lines)
      assert.is_nil(el._lines)
    end)
  end)

  describe('unmount', function()
    it('should set mounted to false', function()
      local el = create_element()
      el:mount()
      el:unmount()
      assert.is_false(el._mounted)
    end)

    it('should return self for chaining', function()
      local el = create_element()
      el:mount()
      local result = el:unmount()
      assert.are.equal(el, result)
    end)

    it('should be idempotent when not mounted', function()
      local el = create_element()
      local result = el:unmount()
      assert.are.equal(el, result)
      assert.is_false(el._mounted)
    end)
  end)

  describe('is_valid', function()
    it('should return false before mount', function()
      local el = create_element()
      assert.is_false(el:is_valid())
    end)

    it('should return true after mount', function()
      local el = create_element()
      el:mount()
      assert.is_true(el:is_valid())
    end)

    it('should return false after unmount', function()
      local el = create_element()
      el:mount()
      el:unmount()
      assert.is_false(el:is_valid())
    end)
  end)

  describe('buffer operations', function()
    it('should set and get lines', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'line1', 'line2', 'line3' })
      local lines = el:get_lines()
      eq({ 'line1', 'line2', 'line3' }, lines)
    end)

    it('should clear lines', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'line1', 'line2' })
      el:clear_lines()
      local lines = el:get_lines()
      eq({ '' }, lines)
    end)

    it('should get line count', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'a', 'b', 'c' })
      assert.are.equal(3, el:get_line_count())
    end)

    it('should return empty table for get_lines when not valid', function()
      local el = create_element()
      eq({}, el:get_lines())
    end)

    it('should return 0 for get_line_count when not valid', function()
      local el = create_element()
      assert.are.equal(0, el:get_line_count())
    end)

    it('should return self for set_lines when not valid', function()
      local el = create_element()
      local result = el:set_lines({ 'a' })
      assert.are.equal(el, result)
    end)
  end)

  describe('cursor operations', function()
    it('should set and get cursor', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'line1', 'line2', 'line3' })
      el:set_cursor({ 2, 0 })
      local cursor = el:get_cursor()
      assert.are.equal(2, cursor[1])
      assert.are.equal(0, cursor[2])
    end)

    it('should set and get lnum', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'line1', 'line2', 'line3' })
      el:set_lnum(3)
      assert.are.equal(3, el:get_lnum())
    end)

    it('should reset cursor to {1, 1}', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'line1', 'line2' })
      el:set_cursor({ 2, 0 })
      el:reset_cursor()
      local cursor = el:get_cursor()
      assert.are.equal(1, cursor[1])
    end)

    it('should return default cursor when not valid', function()
      local el = create_element()
      local cursor = el:get_cursor()
      eq({ 1, 1 }, cursor)
    end)

    it('should return 1 for get_lnum when not valid', function()
      local el = create_element()
      assert.are.equal(1, el:get_lnum())
    end)
  end)

  describe('window dimensions', function()
    it('should get width', function()
      local el = create_element()
      el:mount()
      local width = el:get_width()
      assert.are.equal(40, width)
    end)

    it('should get height', function()
      local el = create_element()
      el:mount()
      local height = el:get_height()
      assert.are.equal(10, height)
    end)

    it('should return 0 for width when not valid', function()
      local el = create_element()
      assert.are.equal(0, el:get_width())
    end)

    it('should return 0 for height when not valid', function()
      local el = create_element()
      assert.are.equal(0, el:get_height())
    end)
  end)

  describe('focus', function()
    it('should focus the element window', function()
      local el = create_element()
      el:mount()
      el:focus()
      assert.is_true(el:is_focused())
    end)

    it('should return false for is_focused when not valid', function()
      local el = create_element()
      assert.is_false(el:is_focused())
    end)
  end)

  describe('filetype', function()
    it('should set and get filetype', function()
      local el = create_element()
      el:mount()
      el:set_filetype('lua')
      assert.are.equal('lua', el:get_filetype())
    end)

    it('should return empty string for get_filetype when not valid', function()
      local el = create_element()
      assert.are.equal('', el:get_filetype())
    end)
  end)

  describe('get_bufnr and get_win_id', function()
    it('should return valid bufnr after mount', function()
      local el = create_element()
      el:mount()
      local bufnr = el:get_bufnr()
      assert.is_not_nil(bufnr)
      assert.is_true(type(bufnr) == 'number')
      assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    end)

    it('should return valid win_id after mount', function()
      local el = create_element()
      el:mount()
      local win_id = el:get_win_id()
      assert.is_not_nil(win_id)
      assert.is_true(type(win_id) == 'number')
      assert.is_true(vim.api.nvim_win_is_valid(win_id))
    end)

    it('should return nil for bufnr before mount', function()
      local el = create_element()
      assert.is_nil(el:get_bufnr())
    end)

    it('should return nil for win_id before mount', function()
      local el = create_element()
      assert.is_nil(el:get_win_id())
    end)
  end)

  describe('window options', function()
    it('should update window options', function()
      local el = create_element()
      el:mount()
      el:update_window_options({ wrap = true })
      assert.is_true(el._config.win_options.wrap)
    end)

    it('should be a no-op when new_options is nil', function()
      local el = create_element()
      el:mount()
      local result = el:update_window_options(nil)
      assert.are.equal(el, result)
    end)

    it('should enable cursorline', function()
      local el = create_element()
      el:mount()
      el:enable_cursorline()
      -- Verify the option was set via window
      local ok, value = pcall(vim.api.nvim_get_option_value, 'cursorline', { win = el:get_win_id() })
      if ok then
        assert.is_true(value)
      end
    end)

    it('should disable cursorline', function()
      local el = create_element()
      el:mount()
      el:enable_cursorline()
      el:disable_cursorline()
      local ok, value = pcall(vim.api.nvim_get_option_value, 'cursorline', { win = el:get_win_id() })
      if ok then
        assert.is_false(value)
      end
    end)
  end)

  describe('extmarks', function()
    it('should place and clear extmarks without error', function()
      local el = create_element()
      el:mount()
      el:set_lines({ 'hello world' })
      assert.has_no.errors(function()
        el:clear_extmarks()
      end)
    end)

    it('should return nil for place_extmark_highlight when not valid', function()
      local el = create_element()
      assert.is_nil(el:place_extmark_highlight({}))
    end)

    it('should return nil for place_extmark_text when not valid', function()
      local el = create_element()
      assert.is_nil(el:place_extmark_text({}))
    end)

    it('should return nil for place_extmark_lnum when not valid', function()
      local el = create_element()
      assert.is_nil(el:place_extmark_lnum({}))
    end)
  end)

  describe('guards when not valid', function()
    it('should return self for set_cursor', function()
      local el = create_element()
      assert.are.equal(el, el:set_cursor({ 1, 0 }))
    end)

    it('should return self for set_lnum', function()
      local el = create_element()
      assert.are.equal(el, el:set_lnum(1))
    end)

    it('should return self for focus', function()
      local el = create_element()
      assert.are.equal(el, el:focus())
    end)

    it('should return self for set_filetype', function()
      local el = create_element()
      assert.are.equal(el, el:set_filetype('lua'))
    end)

    it('should return self for clear_extmarks', function()
      local el = create_element()
      assert.are.equal(el, el:clear_extmarks())
    end)

    it('should return self for set_keymap', function()
      local el = create_element()
      assert.are.equal(el, el:set_keymap('n', 'q', function() end))
    end)

    it('should return self for on', function()
      local el = create_element()
      assert.are.equal(el, el:on('BufEnter', function() end))
    end)

    it('should return self for set_width', function()
      local el = create_element()
      assert.are.equal(el, el:set_width(50))
    end)

    it('should return self for set_height', function()
      local el = create_element()
      assert.are.equal(el, el:set_height(20))
    end)

    it('should return self for position_cursor', function()
      local el = create_element()
      assert.are.equal(el, el:position_cursor('center'))
    end)
  end)
end)
