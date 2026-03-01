-- Stub vim functions that cause async scheduling issues in tests
-- (saved so they can be restored after each test to avoid cross-file pollution)
local original_defer_fn = vim.defer_fn
local original_cmd = vim.cmd

-- Save original package.loaded entries so they can be restored after each test
local original_loaded = {
  ['vgit.core.event'] = package.loaded['vgit.core.event'],
  ['vgit.core.Window'] = package.loaded['vgit.core.Window'],
  ['vgit.core.navigation'] = package.loaded['vgit.core.navigation'],
  ['vgit.core.console'] = package.loaded['vgit.core.console'],
  ['vgit.git.git_buffer_store'] = package.loaded['vgit.git.git_buffer_store'],
  ['vgit.settings.live_gutter'] = package.loaded['vgit.settings.live_gutter'],
}

-- Stubs for all dependencies
local enabled_value = true
local live_gutter_stub = {
  get = function(self, key)
    if key == 'enabled' then return enabled_value end
    if key == 'edge_navigation' then return false end
    return nil
  end,
}

local current_buffer = nil
local git_buffer_store_stub = {
  current = function()
    return current_buffer
  end,
  dispatch = function() end,
  on = function() end,
  for_each = function() end,
}

local navigation_up_called = false
local navigation_up_args = {}
local navigation_down_called = false
local navigation_down_args = {}
local navigation_stub = {
  up = function(window, hunks)
    navigation_up_called = true
    navigation_up_args = { window = window, hunks = hunks }
  end,
  down = function(window, hunks)
    navigation_down_called = true
    navigation_down_args = { window = window, hunks = hunks }
  end,
}

local console_error_called = false
local console_error_msg = nil
local console_stub = {
  debug = {
    error = function(msg)
      console_error_called = true
      console_error_msg = msg
    end,
  },
  error = function() end,
  info = function() end,
}

local event_stub = {
  await = function() end,
  async = function(fn)
    return fn
  end,
  debounce_async = function(fn, delay)
    return fn, function() end
  end,
}

local window_lnum = 1
local window_set_lnum_called = false
local window_set_lnum_value = nil
local window_instance = {
  get_cursor = function()
    return { window_lnum, 0 }
  end,
  get_lnum = function()
    return window_lnum
  end,
  set_lnum = function(self, lnum)
    window_set_lnum_called = true
    window_set_lnum_value = lnum
  end,
}
local Window_stub = setmetatable({}, {
  __index = {},
  __call = function(_, ...)
    return window_instance
  end,
})

-- Install stubs BEFORE requiring Hunks
package.loaded['vgit.core.event'] = event_stub
package.loaded['vgit.core.Window'] = Window_stub
package.loaded['vgit.core.navigation'] = navigation_stub
package.loaded['vgit.core.console'] = console_stub
package.loaded['vgit.git.git_buffer_store'] = git_buffer_store_stub
package.loaded['vgit.settings.live_gutter'] = live_gutter_stub

local Hunks = require('vgit.features.buffer.Hunks')

local eq = assert.are.same

-- Helper to create a mock buffer with configurable behavior
local function make_mock_buffer(opts)
  opts = opts or {}
  local buffer = {
    _set_lines_calls = {},
    _stage_called = false,
    _stage_hunk_called = false,
    _stage_hunk_arg = nil,
    _unstage_called = false,
    git_file = {
      lines = function()
        return opts.git_file_lines or { 'original line' }, opts.git_file_lines_err
      end,
    },
  }
  function buffer:get_hunks()
    return opts.hunks
  end
  function buffer:get_lines()
    return opts.lines or {}
  end
  function buffer:set_lines(lines_or_range, top, bot)
    buffer._set_lines_calls[#buffer._set_lines_calls + 1] = {
      lines = lines_or_range,
      top = top,
      bot = bot,
    }
  end
  function buffer:stage()
    buffer._stage_called = true
    return opts.stage_result, opts.stage_err
  end
  function buffer:stage_hunk(hunk)
    buffer._stage_hunk_called = true
    buffer._stage_hunk_arg = hunk
    return opts.stage_hunk_result, opts.stage_hunk_err
  end
  function buffer:unstage()
    buffer._unstage_called = true
    return opts.unstage_result, opts.unstage_err
  end
  function buffer:is_tracked()
    return opts.is_tracked ~= false
  end
  function buffer:is_modified()
    return opts.editing == true
  end
  function buffer:is_valid()
    return opts.is_valid ~= false
  end
  return buffer
end

-- Reset shared state before each test
local function reset_state()
  enabled_value = true
  current_buffer = nil
  window_lnum = 1
  window_set_lnum_called = false
  window_set_lnum_value = nil
  navigation_up_called = false
  navigation_up_args = {}
  navigation_down_called = false
  navigation_down_args = {}
  console_error_called = false
  console_error_msg = nil
end

describe('Hunks:', function()
  local hunks_instance

  before_each(function()
    vim.defer_fn = function(fn, ms) end
    vim.cmd = function(cmd) end
    -- Re-apply stubs (a prior test file may have restored originals to package.loaded)
    package.loaded['vgit.core.event'] = event_stub
    package.loaded['vgit.core.Window'] = Window_stub
    package.loaded['vgit.core.navigation'] = navigation_stub
    package.loaded['vgit.core.console'] = console_stub
    package.loaded['vgit.git.git_buffer_store'] = git_buffer_store_stub
    package.loaded['vgit.settings.live_gutter'] = live_gutter_stub
    reset_state()
    hunks_instance = Hunks()
  end)

  after_each(function()
    vim.defer_fn = original_defer_fn
    vim.cmd = original_cmd
    -- Restore package.loaded so subsequent test files see real modules
    package.loaded['vgit.core.event'] = original_loaded['vgit.core.event']
    package.loaded['vgit.core.Window'] = original_loaded['vgit.core.Window']
    package.loaded['vgit.core.navigation'] = original_loaded['vgit.core.navigation']
    package.loaded['vgit.core.console'] = original_loaded['vgit.core.console']
    package.loaded['vgit.git.git_buffer_store'] = original_loaded['vgit.git.git_buffer_store']
    package.loaded['vgit.settings.live_gutter'] = original_loaded['vgit.settings.live_gutter']
  end)

  describe('constructor', function()
    it('should create an instance with name "Buffer Hunks"', function()
      eq('Buffer Hunks', hunks_instance._name)
    end)

    it('should be an instance of Hunks', function()
      assert.is_true(hunks_instance:is(Hunks))
    end)
  end)

  describe('is_enabled', function()
    it('should return true when live_gutter enabled is true', function()
      enabled_value = true
      assert.is_true(hunks_instance:is_enabled())
    end)

    it('should return false when live_gutter enabled is false', function()
      enabled_value = false
      assert.is_false(hunks_instance:is_enabled())
    end)

    it('should return false when live_gutter enabled is nil', function()
      enabled_value = nil
      assert.is_false(hunks_instance:is_enabled())
    end)
  end)

  describe('hunk_up', function()
    it('should return early when not enabled', function()
      enabled_value = false
      hunks_instance:hunk_up()
      assert.is_false(navigation_up_called)
    end)

    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:hunk_up()
      assert.is_false(navigation_up_called)
    end)

    it('should return early when buffer has no hunks', function()
      current_buffer = make_mock_buffer({ hunks = {} })
      hunks_instance:hunk_up()
      assert.is_false(navigation_up_called)
    end)

    it('should return early when buffer hunks is nil', function()
      current_buffer = make_mock_buffer({ hunks = nil })
      hunks_instance:hunk_up()
      assert.is_false(navigation_up_called)
    end)

    it('should call navigation.up with window and hunks when hunks exist', function()
      local test_hunks = { { top = 5, bot = 10 }, { top = 20, bot = 30 } }
      current_buffer = make_mock_buffer({ hunks = test_hunks })
      hunks_instance:hunk_up()
      assert.is_true(navigation_up_called)
      eq(test_hunks, navigation_up_args.hunks)
    end)
  end)

  describe('hunk_down', function()
    it('should return early when not enabled', function()
      enabled_value = false
      hunks_instance:hunk_down()
      assert.is_false(navigation_down_called)
    end)

    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:hunk_down()
      assert.is_false(navigation_down_called)
    end)

    it('should return early when buffer has no hunks', function()
      current_buffer = make_mock_buffer({ hunks = {} })
      hunks_instance:hunk_down()
      assert.is_false(navigation_down_called)
    end)

    it('should return early when buffer hunks is nil', function()
      current_buffer = make_mock_buffer({ hunks = nil })
      hunks_instance:hunk_down()
      assert.is_false(navigation_down_called)
    end)

    it('should call navigation.down with window and hunks when hunks exist', function()
      local test_hunks = { { top = 5, bot = 10 }, { top = 20, bot = 30 } }
      current_buffer = make_mock_buffer({ hunks = test_hunks })
      hunks_instance:hunk_down()
      assert.is_true(navigation_down_called)
      eq(test_hunks, navigation_down_args.hunks)
    end)
  end)

  describe('cursor_hunk', function()
    it('should return nil when no current buffer', function()
      current_buffer = nil
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should return nil when buffer has no hunks', function()
      current_buffer = make_mock_buffer({ hunks = nil })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should return nil when no hunks in list', function()
      current_buffer = make_mock_buffer({ hunks = {} })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should return hunk when cursor is at lnum=1 and hunk has top=0 bot=0 (delete at top)', function()
      window_lnum = 1
      local test_hunk = { top = 0, bot = 0, type = 'remove', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(test_hunk, hunk)
      eq(1, index)
    end)

    it('should return hunk when lnum is between hunk.top and hunk.bot', function()
      window_lnum = 7
      local test_hunk = { top = 5, bot = 10, type = 'change', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(test_hunk, hunk)
      eq(1, index)
    end)

    it('should return hunk when lnum equals hunk.top exactly', function()
      window_lnum = 5
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(test_hunk, hunk)
      eq(1, index)
    end)

    it('should return hunk when lnum equals hunk.bot exactly', function()
      window_lnum = 10
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(test_hunk, hunk)
      eq(1, index)
    end)

    it('should return nil when lnum is not within any hunk range', function()
      window_lnum = 15
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should return nil when lnum is before hunk range', function()
      window_lnum = 3
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should return correct hunk when multiple hunks exist and cursor is in second hunk', function()
      window_lnum = 25
      local hunk1 = { top = 5, bot = 10, type = 'add', diff = {} }
      local hunk2 = { top = 20, bot = 30, type = 'change', diff = {} }
      local hunk3 = { top = 40, bot = 50, type = 'remove', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { hunk1, hunk2, hunk3 } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(hunk2, hunk)
      eq(2, index)
    end)

    it('should return correct hunk when multiple hunks exist and cursor is in third hunk', function()
      window_lnum = 45
      local hunk1 = { top = 5, bot = 10, type = 'add', diff = {} }
      local hunk2 = { top = 20, bot = 30, type = 'change', diff = {} }
      local hunk3 = { top = 40, bot = 50, type = 'remove', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { hunk1, hunk2, hunk3 } })
      local hunk, index = hunks_instance:cursor_hunk()
      eq(hunk3, hunk)
      eq(3, index)
    end)

    it('should return nil when cursor is between hunks', function()
      window_lnum = 15
      local hunk1 = { top = 5, bot = 10, type = 'add', diff = {} }
      local hunk2 = { top = 20, bot = 30, type = 'change', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { hunk1, hunk2 } })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)

    it('should not match top=0 bot=0 hunk when lnum is not 1', function()
      window_lnum = 5
      local test_hunk = { top = 0, bot = 0, type = 'remove', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk } })
      local hunk, index = hunks_instance:cursor_hunk()
      assert.is_nil(hunk)
      assert.is_nil(index)
    end)
  end)

  describe('stage_all', function()
    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:stage_all()
      -- No error thrown, no calls made
    end)

    it('should call buffer:stage()', function()
      current_buffer = make_mock_buffer()
      hunks_instance:stage_all()
      assert.is_true(current_buffer._stage_called)
    end)

    it('should call console.debug.error when stage returns an error', function()
      current_buffer = make_mock_buffer({ stage_err = 'stage failed' })
      hunks_instance:stage_all()
      assert.is_true(console_error_called)
      eq('stage failed', console_error_msg)
    end)

    it('should not call console.debug.error when stage succeeds', function()
      current_buffer = make_mock_buffer()
      hunks_instance:stage_all()
      assert.is_false(console_error_called)
    end)
  end)

  describe('cursor_stage', function()
    it('should return early when not enabled', function()
      enabled_value = false
      current_buffer = make_mock_buffer()
      hunks_instance:cursor_stage()
      assert.is_false(current_buffer._stage_called)
      assert.is_false(current_buffer._stage_hunk_called)
    end)

    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:cursor_stage()
      -- No error thrown
    end)

    it('should return early when buffer is modified', function()
      current_buffer = make_mock_buffer({ editing = true })
      hunks_instance:cursor_stage()
      assert.is_false(current_buffer._stage_called)
      assert.is_false(current_buffer._stage_hunk_called)
    end)

    it('should call buffer:stage() when buffer is not tracked', function()
      current_buffer = make_mock_buffer({ is_tracked = false })
      hunks_instance:cursor_stage()
      assert.is_true(current_buffer._stage_called)
      assert.is_false(current_buffer._stage_hunk_called)
    end)

    it('should call console.debug.error when untracked buffer stage fails', function()
      current_buffer = make_mock_buffer({ is_tracked = false, stage_err = 'untracked error' })
      hunks_instance:cursor_stage()
      assert.is_true(console_error_called)
      eq('untracked error', console_error_msg)
    end)

    it('should call buffer:stage_hunk() when buffer is tracked and cursor is on a hunk', function()
      window_lnum = 7
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk }, is_tracked = true })
      hunks_instance:cursor_stage()
      assert.is_true(current_buffer._stage_hunk_called)
      eq(test_hunk, current_buffer._stage_hunk_arg)
    end)

    it('should not call stage_hunk when cursor is not on any hunk', function()
      window_lnum = 50
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({ hunks = { test_hunk }, is_tracked = true })
      hunks_instance:cursor_stage()
      assert.is_false(current_buffer._stage_hunk_called)
    end)

    it('should call console.debug.error when stage_hunk returns an error', function()
      window_lnum = 7
      local test_hunk = { top = 5, bot = 10, type = 'add', diff = {} }
      current_buffer = make_mock_buffer({
        hunks = { test_hunk },
        is_tracked = true,
        stage_hunk_err = 'hunk stage error',
      })
      hunks_instance:cursor_stage()
      assert.is_true(console_error_called)
      eq('hunk stage error', console_error_msg)
    end)
  end)

  describe('unstage_all', function()
    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:unstage_all()
      -- No error thrown
    end)

    it('should call buffer:unstage()', function()
      current_buffer = make_mock_buffer()
      hunks_instance:unstage_all()
      assert.is_true(current_buffer._unstage_called)
    end)

    it('should call console.debug.error when unstage returns an error', function()
      current_buffer = make_mock_buffer({ unstage_err = 'unstage failed' })
      hunks_instance:unstage_all()
      assert.is_true(console_error_called)
      eq('unstage failed', console_error_msg)
    end)

    it('should not call console.debug.error when unstage succeeds', function()
      current_buffer = make_mock_buffer()
      hunks_instance:unstage_all()
      assert.is_false(console_error_called)
    end)
  end)

  describe('reset_all', function()
    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:reset_all()
      -- No error thrown
    end)

    it('should return early when buffer has no hunks', function()
      current_buffer = make_mock_buffer({ hunks = {} })
      hunks_instance:reset_all()
      eq(0, #current_buffer._set_lines_calls)
    end)

    it('should return early when buffer hunks is nil', function()
      current_buffer = make_mock_buffer({ hunks = nil })
      hunks_instance:reset_all()
      eq(0, #current_buffer._set_lines_calls)
    end)

    it('should call buffer:set_lines with original lines from git_file', function()
      local original_lines = { 'line 1', 'line 2', 'line 3' }
      current_buffer = make_mock_buffer({
        hunks = { { top = 1, bot = 3, type = 'change', diff = {} } },
        git_file_lines = original_lines,
      })
      hunks_instance:reset_all()
      eq(1, #current_buffer._set_lines_calls)
      eq(original_lines, current_buffer._set_lines_calls[1].lines)
    end)

    it('should call console.debug.error when git_file:lines returns an error', function()
      current_buffer = make_mock_buffer({
        hunks = { { top = 1, bot = 3, type = 'change', diff = {} } },
        git_file_lines_err = 'file read error',
      })
      hunks_instance:reset_all()
      assert.is_true(console_error_called)
      eq('file read error', console_error_msg)
    end)

    it('should not call set_lines when git_file:lines returns an error', function()
      current_buffer = make_mock_buffer({
        hunks = { { top = 1, bot = 3, type = 'change', diff = {} } },
        git_file_lines_err = 'file read error',
      })
      hunks_instance:reset_all()
      eq(0, #current_buffer._set_lines_calls)
    end)
  end)

  describe('cursor_reset', function()
    it('should return early when not enabled', function()
      enabled_value = false
      current_buffer = make_mock_buffer()
      hunks_instance:cursor_reset()
      eq(0, #current_buffer._set_lines_calls)
    end)

    it('should return early when no current buffer', function()
      current_buffer = nil
      hunks_instance:cursor_reset()
      -- No error thrown
    end)

    it('should return early when buffer has no hunks', function()
      current_buffer = make_mock_buffer({ hunks = nil })
      hunks_instance:cursor_reset()
      eq(0, #current_buffer._set_lines_calls)
    end)

    describe('reset_all shortcut at lnum=1 with empty buffer and all remove hunks', function()
      it('should call reset_all when lnum=1, single empty line, all hunks are remove type', function()
        window_lnum = 1
        local original_lines = { 'restored line 1', 'restored line 2' }
        current_buffer = make_mock_buffer({
          hunks = {
            { top = 0, bot = 0, type = 'remove', diff = {} },
          },
          lines = { '' },
          git_file_lines = original_lines,
        })
        hunks_instance:cursor_reset()
        -- reset_all should have been called, which calls set_lines with git_file lines
        -- But since the hunk also matches (top=0, bot=0 with lnum=1), cursor reset logic also runs.
        -- The first set_lines call comes from reset_all
        assert.is_true(#current_buffer._set_lines_calls >= 1)
        eq(original_lines, current_buffer._set_lines_calls[1].lines)
      end)

      it('should not call reset_all when buffer has non-empty content', function()
        window_lnum = 1
        local test_hunk = { top = 0, bot = 0, type = 'remove', diff = { '-removed line' } }
        current_buffer = make_mock_buffer({
          hunks = { test_hunk },
          lines = { 'some content' },
        })
        hunks_instance:cursor_reset()
        -- reset_all not triggered because buffer is not empty single line
        -- But the hunk is still matched via the second loop (top=0 bot=0 lnum=1)
        local found_reset_all_call = false
        for _, call in ipairs(current_buffer._set_lines_calls) do
          if call.top == nil and call.bot == nil then found_reset_all_call = true end
        end
        assert.is_false(found_reset_all_call)
      end)

      it('should not call reset_all when hunks include non-remove types', function()
        window_lnum = 1
        current_buffer = make_mock_buffer({
          hunks = {
            { top = 0, bot = 0, type = 'remove', diff = {} },
            { top = 5, bot = 10, type = 'add', diff = {} },
          },
          lines = { '' },
        })
        hunks_instance:cursor_reset()
        -- reset_all not triggered because not all hunks are remove type
        local found_reset_all_call = false
        for _, call in ipairs(current_buffer._set_lines_calls) do
          if call.top == nil and call.bot == nil then found_reset_all_call = true end
        end
        assert.is_false(found_reset_all_call)
      end)
    end)

    describe('hunk selection and line replacement', function()
      it('should find and reset a hunk when cursor is within its range', function()
        window_lnum = 7
        local test_hunk = {
          top = 5,
          bot = 10,
          type = 'change',
          diff = { '-old line 1', '-old line 2', '+new line 1', '+new line 2' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        eq(1, #current_buffer._set_lines_calls)
        local call = current_buffer._set_lines_calls[1]
        eq({ 'old line 1', 'old line 2' }, call.lines)
        -- For non-remove hunks: top - 1, bot
        eq(4, call.top)
        eq(10, call.bot)
      end)

      it('should use top, bot (not top-1) for remove type hunks', function()
        window_lnum = 1
        local test_hunk = {
          top = 0,
          bot = 0,
          type = 'remove',
          diff = { '-deleted line 1', '-deleted line 2' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk }, lines = { 'content' } })
        hunks_instance:cursor_reset()
        -- Find the set_lines call with top/bot (not the reset_all one)
        local found = false
        for _, call in ipairs(current_buffer._set_lines_calls) do
          if call.top ~= nil then
            eq({ 'deleted line 1', 'deleted line 2' }, call.lines)
            eq(0, call.top)
            eq(0, call.bot)
            found = true
          end
        end
        assert.is_true(found)
      end)

      it('should extract only removed lines (starting with -) from diff', function()
        window_lnum = 5
        local test_hunk = {
          top = 5,
          bot = 5,
          type = 'change',
          diff = { '-removed', '+added', ' context', '-also removed' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        eq(1, #current_buffer._set_lines_calls)
        eq({ 'removed', 'also removed' }, current_buffer._set_lines_calls[1].lines)
      end)

      it('should strip the leading - character from removed lines', function()
        window_lnum = 5
        local test_hunk = {
          top = 5,
          bot = 5,
          type = 'change',
          diff = { '-  indented removed line' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        eq({ '  indented removed line' }, current_buffer._set_lines_calls[1].lines)
      end)

      it('should produce empty replaced_lines when diff has no removed lines', function()
        window_lnum = 5
        local test_hunk = {
          top = 5,
          bot = 7,
          type = 'add',
          diff = { '+added line 1', '+added line 2', '+added line 3' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        eq(1, #current_buffer._set_lines_calls)
        eq({}, current_buffer._set_lines_calls[1].lines)
        -- For non-remove hunks: top - 1, bot
        eq(4, current_buffer._set_lines_calls[1].top)
        eq(7, current_buffer._set_lines_calls[1].bot)
      end)

      it('should set window lnum to hunk.top when top >= 1', function()
        window_lnum = 7
        local test_hunk = {
          top = 5,
          bot = 10,
          type = 'change',
          diff = { '-old line' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        assert.is_true(window_set_lnum_called)
        eq(5, window_set_lnum_value)
      end)

      it('should set window lnum to 1 when hunk.top is 0', function()
        window_lnum = 1
        local test_hunk = {
          top = 0,
          bot = 0,
          type = 'remove',
          diff = { '-removed' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk }, lines = { 'content' } })
        hunks_instance:cursor_reset()
        assert.is_true(window_set_lnum_called)
        eq(1, window_set_lnum_value)
      end)

      it('should remove the hunk from the hunks table after resetting', function()
        window_lnum = 7
        local hunk1 = { top = 5, bot = 10, type = 'change', diff = { '-old' } }
        local hunk2 = { top = 20, bot = 30, type = 'add', diff = { '+new' } }
        local test_hunks = { hunk1, hunk2 }
        current_buffer = make_mock_buffer({ hunks = test_hunks })
        hunks_instance:cursor_reset()
        -- The selected hunk should be removed from the hunks table
        eq(1, #test_hunks)
        eq(hunk2, test_hunks[1])
      end)

      it('should do nothing when cursor is not on any hunk', function()
        window_lnum = 50
        local test_hunk = {
          top = 5,
          bot = 10,
          type = 'change',
          diff = { '-old line' },
        }
        current_buffer = make_mock_buffer({ hunks = { test_hunk } })
        hunks_instance:cursor_reset()
        eq(0, #current_buffer._set_lines_calls)
        assert.is_false(window_set_lnum_called)
      end)

      it('should match hunk with top=0 bot=0 when lnum=1 via alternative condition', function()
        window_lnum = 1
        local test_hunk = {
          top = 0,
          bot = 0,
          type = 'remove',
          diff = { '-line to restore' },
        }
        -- Buffer has actual content so reset_all shortcut is not triggered
        current_buffer = make_mock_buffer({ hunks = { test_hunk }, lines = { 'existing content' } })
        hunks_instance:cursor_reset()
        -- The hunk should be found via the (hunk.top == 0 and hunk.bot == 0 and lnum - 1 == hunk.top) condition
        local found = false
        for _, call in ipairs(current_buffer._set_lines_calls) do
          if call.top ~= nil then
            eq({ 'line to restore' }, call.lines)
            eq(0, call.top)
            eq(0, call.bot)
            found = true
          end
        end
        assert.is_true(found)
      end)

      it('should select the correct hunk from multiple hunks', function()
        window_lnum = 25
        local hunk1 = { top = 5, bot = 10, type = 'add', diff = { '+line' } }
        local hunk2 = { top = 20, bot = 30, type = 'change', diff = { '-removed', '+added' } }
        local hunk3 = { top = 40, bot = 50, type = 'remove', diff = { '-del' } }
        local test_hunks = { hunk1, hunk2, hunk3 }
        current_buffer = make_mock_buffer({ hunks = test_hunks })
        hunks_instance:cursor_reset()
        eq(1, #current_buffer._set_lines_calls)
        local call = current_buffer._set_lines_calls[1]
        eq({ 'removed' }, call.lines)
        -- Non-remove hunk: top - 1, bot
        eq(19, call.top)
        eq(30, call.bot)
        -- hunk2 should be removed from the table
        eq(2, #test_hunks)
        eq(hunk1, test_hunks[1])
        eq(hunk3, test_hunks[2])
      end)
    end)
  end)
end)
