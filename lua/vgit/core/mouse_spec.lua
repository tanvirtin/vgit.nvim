local eq = assert.are.same
local is_truthy = assert.is_truthy
local is_nil = assert.is_nil

describe('mouse:', function()
  local mouse
  local mappings
  local set_calls
  local del_calls
  local valid_buffers
  local valid_windows
  local window_buffers
  local line_counts
  local current_win_calls
  local cursor_calls
  local mouse_pos

  local api_originals = {}
  local keymap_originals = {}

  local function stub_fn(table, name, impl)
    if keymap_originals[table] == nil then keymap_originals[table] = {} end
    if keymap_originals[table][name] == nil then keymap_originals[table][name] = table[name] end
    table[name] = impl
  end

  local function count_mappings(lhs, mode)
    local total = 0
    for _, call in ipairs(set_calls) do
      if call.lhs == lhs and call.mode == (mode or 'n') then total = total + 1 end
    end
    return total
  end

  local function stub_api(name, impl)
    if api_originals[name] == nil then api_originals[name] = vim.api[name] end
    vim.api[name] = impl
  end

  local function invoke(lhs, mode)
    local mapping = mappings[(mode or 'n') .. '|' .. lhs]
    is_truthy(mapping, 'expected mapping for ' .. lhs)
    mapping.fn()
  end

  before_each(function()
    package.loaded['vgit.core.mouse'] = nil
    mouse = require('vgit.core.mouse')

    mappings = {}
    set_calls = {}
    del_calls = {}
    valid_buffers = { [10] = true }
    valid_windows = { [5] = true }
    window_buffers = { [5] = 10 }
    line_counts = { [10] = 100 }
    current_win_calls = {}
    cursor_calls = {}
    mouse_pos = {
      screenrow = 3,
      screencol = 7,
      line = 12,
      column = 8,
      winid = 5,
      winrow = 2,
      wincol = 4,
    }

    stub_fn(vim.keymap, 'set', function(mode, lhs, fn, opts)
      mappings[mode .. '|' .. lhs] = { fn = fn, opts = opts }
      set_calls[#set_calls + 1] = { mode = mode, lhs = lhs }
    end)

    stub_fn(vim.keymap, 'del', function(mode, lhs)
      del_calls[#del_calls + 1] = { mode = mode, lhs = lhs }
      mappings[mode .. '|' .. lhs] = nil
    end)

    stub_fn(vim.fn, 'getmousepos', function()
      return mouse_pos
    end)

    stub_api('nvim_buf_is_valid', function(bufnr)
      return valid_buffers[bufnr] == true
    end)

    stub_api('nvim_win_is_valid', function(winid)
      return valid_windows[winid] == true
    end)

    stub_api('nvim_set_current_win', function(winid)
      current_win_calls[#current_win_calls + 1] = winid
    end)

    stub_api('nvim_win_get_buf', function(winid)
      return window_buffers[winid]
    end)

    stub_api('nvim_buf_line_count', function(bufnr)
      return line_counts[bufnr]
    end)

    stub_api('nvim_win_set_cursor', function(winid, cursor)
      cursor_calls[#cursor_calls + 1] = { winid = winid, cursor = cursor }
    end)
  end)

  after_each(function()
    for table, entries in pairs(keymap_originals) do
      for name, original in pairs(entries) do
        table[name] = original
      end
    end
    keymap_originals = {}

    for name, original in pairs(api_originals) do
      vim.api[name] = original
    end
    api_originals = {}
  end)

  describe('attach', function()
    it('returns a callable detach for invalid buffer input', function()
      local detach = mouse.attach(nil, { clicks = { [2] = function() end } })
      is_truthy(type(detach) == 'function')

      local invalid_detach = mouse.attach(99, { clicks = { [2] = function() end } })
      is_truthy(type(invalid_detach) == 'function')
    end)

    it('returns a callable detach when clicks are missing', function()
      local detach = mouse.attach(10, {})
      is_truthy(type(detach) == 'function')
      is_nil(mappings['n|<LeftMouse>'])
    end)

    it('creates a buffer-local mapping for each requested click count', function()
      mouse.attach(10, { clicks = { [1] = function() end, [2] = function() end } })

      local single = mappings['n|<LeftMouse>']
      local double = mappings['n|<2-LeftMouse>']
      is_truthy(single)
      is_truthy(double)
      eq(true, single.opts.buffer == 10)
      eq(true, double.opts.buffer == 10)
      is_nil(mappings['n|<3-LeftMouse>'])
    end)

    it('respects custom modes', function()
      mouse.attach(10, { modes = { 'n', 'v' }, clicks = { [2] = function() end } })

      is_truthy(mappings['n|<2-LeftMouse>'])
      is_truthy(mappings['v|<2-LeftMouse>'])
    end)

    it('does not recreate an existing mapping for the same count and mode', function()
      mouse.attach(10, { clicks = { [2] = function() end } })

      mouse.attach(10, { clicks = { [2] = function() end } })

      eq(1, count_mappings('<2-LeftMouse>'))
    end)
  end)

  describe('dispatch', function()
    it('passes click info built from getmousepos to double click handlers', function()
      local received = {}
      mouse.attach(10, {
        clicks = {
          [2] = function(info)
            received[#received + 1] = info
          end,
        },
      })

      invoke('<2-LeftMouse>')

      eq({
        button = 'left',
        count = 2,
        winid = 5,
        lnum = 12,
        col = 8,
        screenrow = 3,
        screencol = 7,
      }, received[1])
      eq(0, #cursor_calls)
    end)

    it('moves the cursor to the clicked position before single click handlers', function()
      local received = {}
      mouse.attach(10, {
        clicks = {
          [1] = function(info)
            received[#received + 1] = info
          end,
        },
      })

      invoke('<LeftMouse>')

      eq({ 5 }, current_win_calls)
      eq({ { winid = 5, cursor = { 12, 7 } } }, cursor_calls)
      eq(12, received[1].lnum)
    end)

    it('clamps the clicked line to the buffer line count', function()
      mouse_pos.line = 500

      mouse.attach(10, { clicks = { [1] = function() end } })
      invoke('<LeftMouse>')

      eq({ { winid = 5, cursor = { 100, 7 } } }, cursor_calls)
    end)

    it('skips cursor placement when the click is outside the text area', function()
      mouse_pos.line = 0

      mouse.attach(10, { clicks = { [1] = function() end } })
      invoke('<LeftMouse>')

      eq(0, #cursor_calls)
      eq(0, #current_win_calls)
    end)

    it('skips cursor placement when the clicked window is invalid', function()
      mouse_pos.winid = 42

      mouse.attach(10, { clicks = { [1] = function() end } })
      invoke('<LeftMouse>')

      eq(0, #cursor_calls)
    end)
  end)

  describe('detach', function()
    it('deletes mappings when the last handler for a count detaches', function()
      local detach = mouse.attach(10, { clicks = { [2] = function() end } })

      detach()

      eq({ { mode = 'n', lhs = '<2-LeftMouse>' } }, del_calls)
    end)

    it('keeps the mapping while another handler is still attached', function()
      local calls = {}
      local detach_a = mouse.attach(
        10,
        { clicks = {
          [2] = function()
            calls[#calls + 1] = 'a'
          end,
        } }
      )
      mouse.attach(10, { clicks = {
        [2] = function()
          calls[#calls + 1] = 'b'
        end,
      } })

      detach_a()
      invoke('<2-LeftMouse>')
      detach_a()

      eq({ 'b' }, calls)
      eq(0, #del_calls)
    end)

    it('invokes every attached handler in registration order', function()
      local calls = {}
      mouse.attach(10, { clicks = {
        [2] = function()
          calls[#calls + 1] = 'a'
        end,
      } })
      mouse.attach(10, { clicks = {
        [2] = function()
          calls[#calls + 1] = 'b'
        end,
      } })

      invoke('<2-LeftMouse>')

      eq({ 'a', 'b' }, calls)
    end)

    it('is idempotent', function()
      local detach = mouse.attach(10, { clicks = { [2] = function() end } })

      detach()
      detach()

      eq(1, #del_calls)
    end)

    it('deletes every mapped mode when the last handler detaches', function()
      local detach_a = mouse.attach(10, { modes = { 'n', 'v' }, clicks = { [2] = function() end } })
      local detach_b = mouse.attach(10, { modes = { 'n' }, clicks = { [2] = function() end } })

      detach_b()
      eq(0, #del_calls)
      is_truthy(mappings['n|<2-LeftMouse>'])
      is_truthy(mappings['v|<2-LeftMouse>'])

      detach_a()
      eq(2, #del_calls)
      assert.is_nil(mappings['n|<2-LeftMouse>'])
      assert.is_nil(mappings['v|<2-LeftMouse>'])
    end)
  end)
end)
