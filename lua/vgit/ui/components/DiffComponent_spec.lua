local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

local function create_diff_component(overrides)
  local DiffComponent = require('vgit.ui.components.DiffComponent')
  local ComponentManager = require('vgit.ui.ComponentManager')
  overrides = overrides or {}

  local component = DiffComponent(overrides.props or {})
  ComponentManager():render({ component = component, mode = 'popup', width = 80, height = 40 })

  -- Apply state overrides
  for k, v in pairs(overrides.state or {}) do
    component.state[k] = v
  end

  -- Compute how many buffer lines are needed
  local max_line = 50
  if overrides.lnum and overrides.lnum > max_line then max_line = overrides.lnum + 5 end
  if overrides.state then
    if overrides.state.marks then
      for _, mark in ipairs(overrides.state.marks) do
        if mark.bot and mark.bot > max_line then max_line = mark.bot + 5 end
      end
    end
    if overrides.state.line_numbers then
      local n = #overrides.state.line_numbers
      if n > max_line then max_line = n end
    end
  end

  -- Populate buffer so cursor movement and extmarks work
  local dummy = {}
  for i = 1, max_line do
    dummy[i] = ''
  end
  component._element:set_lines(dummy)

  -- Set initial cursor position
  if overrides.lnum then component:set_lnum(overrides.lnum) end

  -- Reset viewport state for a clean test baseline
  component._viewport_dirty = true
  component._last_top = nil
  component._last_bot = nil

  return component
end

describe('DiffComponent:', function()
  after_each(ui_helper.cleanup_ui)

  describe('hunk_down', function()
    it('should navigate to first mark when cursor is before all marks', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_down()
      assert.is_not_nil(result)
      eq(5, result.top)
    end)

    it('should navigate to next mark when cursor is inside a mark', function()
      local component = create_diff_component({
        lnum = 7,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_down()
      assert.is_not_nil(result)
      eq(15, result.top) -- second mark
    end)

    it('should wrap to first mark when past last mark', function()
      local component = create_diff_component({
        lnum = 25,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_down()
      assert.is_not_nil(result)
      eq(5, result.top) -- wraps to first
    end)

    it('should wrap when at last mark', function()
      local component = create_diff_component({
        lnum = 17,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_down()
      assert.is_not_nil(result)
      -- mark_index would be 3, which wraps to 1
      eq(5, result.top)
    end)

    it('should return nil for empty marks', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      local result = component:hunk_down()
      eq(nil, result)
    end)

    it('should navigate to next mark when cursor is between marks', function()
      local component = create_diff_component({
        lnum = 12,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
            { top = 25, bot = 30 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_down()
      assert.is_not_nil(result)
      eq(15, result.top) -- mark 2
    end)
  end)

  describe('hunk_up', function()
    it('should navigate to last mark when cursor is after all marks', function()
      local component = create_diff_component({
        lnum = 25,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_up()
      assert.is_not_nil(result)
      eq(15, result.top) -- last mark
    end)

    it('should navigate to previous mark when cursor is inside a mark', function()
      local component = create_diff_component({
        lnum = 17,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_up()
      assert.is_not_nil(result)
      eq(5, result.top) -- first mark
    end)

    it('should wrap to last mark when before first mark', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:hunk_up()
      assert.is_not_nil(result)
      eq(15, result.top) -- wraps to last
    end)

    it('should return nil for empty marks', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      local result = component:hunk_up()
      eq(nil, result)
    end)
  end)

  describe('move_to_hunk', function()
    it('should move to specified mark index', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:move_to_hunk(2)
      assert.is_not_nil(result)
      eq(15, result.top)
    end)

    it('should wrap index < 1 to last mark', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:move_to_hunk(0)
      assert.is_not_nil(result)
      eq(15, result.top) -- wraps to last
    end)

    it('should wrap index > #marks to first mark', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:move_to_hunk(5)
      assert.is_not_nil(result)
      eq(5, result.top) -- wraps to first
    end)

    it('should return nil for empty marks', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      local result = component:move_to_hunk(1)
      eq(nil, result)
    end)

    it('should default to index 1 when nil', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local result = component:move_to_hunk(nil)
      assert.is_not_nil(result)
      eq(5, result.top) -- first mark
    end)
  end)

  describe('get_hunk_under_cursor', function()
    it('should return hunk when cursor is inside a mark', function()
      local hunk1 = { header = '@@ -1,3 +1,4 @@', diff = {} }
      local hunk2 = { header = '@@ -10,3 +10,4 @@', diff = {} }
      local component = create_diff_component({
        lnum = 7,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = { hunk1, hunk2 },
        },
      })

      local hunk, index = component:get_hunk_under_cursor()
      eq(hunk1, hunk)
      eq(1, index)
    end)

    it('should return nil when cursor is not inside any mark', function()
      local component = create_diff_component({
        lnum = 12,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = { {}, {} },
        },
      })

      local hunk = component:get_hunk_under_cursor()
      eq(nil, hunk)
    end)

    it('should return nil for empty marks', function()
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      local hunk = component:get_hunk_under_cursor()
      eq(nil, hunk)
    end)
  end)

  describe('get_current_mark_under_cursor', function()
    it('should return mark when cursor is inside', function()
      local component = create_diff_component({
        lnum = 7,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local mark, index = component:get_current_mark_under_cursor()
      eq(5, mark.top)
      eq(10, mark.bot)
      eq(1, index)
    end)

    it('should return nil when cursor is outside all marks', function()
      local component = create_diff_component({
        lnum = 12,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10 },
            { top = 15, bot = 20 },
          },
          hunks = {},
        },
      })

      local mark = component:get_current_mark_under_cursor()
      eq(nil, mark)
    end)
  end)

  describe('get_relative_mark_index', function()
    it('should return index when lnum is inside a mark', function()
      local component = create_diff_component({
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10, top_relative = 5, bot_relative = 10 },
            { top = 15, bot = 20, top_relative = 15, bot_relative = 20 },
          },
          hunks = {},
        },
      })

      eq(1, component:get_relative_mark_index(7))
      eq(2, component:get_relative_mark_index(17))
    end)

    it('should return 1 for empty marks', function()
      local component = create_diff_component({
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      eq(1, component:get_relative_mark_index(5))
    end)

    it('should return 1 when lnum is not inside any mark', function()
      local component = create_diff_component({
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {
            { top = 5, bot = 10, top_relative = 5, bot_relative = 10 },
          },
          hunks = {},
        },
      })

      eq(1, component:get_relative_mark_index(12))
    end)
  end)

  describe('get_initial_state', function()
    it('should return expected default state', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      local state = component:get_initial_state()

      eq({}, state.lines)
      eq({}, state.line_numbers)
      eq({}, state.lines_changes)
      eq({}, state.folds)
      eq({}, state.marks)
      eq({}, state.hunks)
    end)
  end)

  describe('get_marks', function()
    it('should return marks from state', function()
      local marks = {
        { top = 1, bot = 5 },
        { top = 10, bot = 15 },
      }
      local component = create_diff_component({
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = marks,
          hunks = {},
        },
      })

      eq(marks, component:get_marks())
    end)

    it('should return empty table when no marks', function()
      local component = create_diff_component({
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })

      eq({}, component:get_marks())
    end)
  end)

  describe('render_diff', function()
    it('should render line numbers for the specified range', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {
            { '1', 'GitLineNr' },
            { '2', 'GitLineNr' },
            { '3', 'GitSignsAdd' },
            { '4', 'GitLineNr' },
            { '5', 'GitLineNr' },
          },
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      -- Render only lines 2-4 (viewport)
      component:render_diff(2, 4)

      eq(3, #lnum_calls)
      eq(1, lnum_calls[1].row) -- line 2, 0-indexed
      eq(2, lnum_calls[2].row) -- line 3, 0-indexed
      eq(3, lnum_calls[3].row) -- line 4, 0-indexed
    end)

    it('should not render line numbers when line_numbers is empty', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {},
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      component:render_diff(1, 5)
      eq(0, #lnum_calls)
    end)

    it('should clamp to line_numbers length', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {
            { '1', 'GitLineNr' },
            { '2', 'GitLineNr' },
          },
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      -- Request range beyond line_numbers length
      component:render_diff(1, 100)
      eq(2, #lnum_calls)
    end)
  end)

  describe('viewport dirty tracking', function()
    it('should skip render_diff when viewport is unchanged', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {
            { '1', 'GitLineNr' },
            { '2', 'GitLineNr' },
            { '3', 'GitLineNr' },
          },
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      -- First call should render
      component:render_diff(1, 3)
      eq(3, #lnum_calls)

      -- Second call with same range should skip (no new calls)
      component:render_diff(1, 3)
      eq(3, #lnum_calls)
    end)

    it('should re-render when viewport range changes', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {
            { '1', 'GitLineNr' },
            { '2', 'GitLineNr' },
            { '3', 'GitLineNr' },
            { '4', 'GitLineNr' },
            { '5', 'GitLineNr' },
          },
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      component:render_diff(1, 3)
      eq(3, #lnum_calls)

      -- Different range should render
      component:render_diff(3, 5)
      eq(6, #lnum_calls)
    end)

    it('should re-render after _viewport_dirty is set', function()
      local lnum_calls = {}
      local component = create_diff_component({
        lnum = 1,
        state = {
          lines = {},
          line_numbers = {
            { '1', 'GitLineNr' },
            { '2', 'GitLineNr' },
          },
          lines_changes = {},
          folds = {},
          marks = {},
          hunks = {},
        },
      })
      local orig = component._element.place_extmark_lnum
      component._element.place_extmark_lnum = function(self_el, opts)
        lnum_calls[#lnum_calls + 1] = opts
        return orig(self_el, opts)
      end

      component:render_diff(1, 2)
      eq(2, #lnum_calls)

      -- Mark dirty and re-render same range
      component._viewport_dirty = true
      component:render_diff(1, 2)
      eq(4, #lnum_calls)
    end)
  end)

  describe('get_lnum', function()
    it('should return lnum from element', function()
      local component = create_diff_component({ lnum = 42 })
      eq(42, component:get_lnum())
    end)
  end)

  describe('get_cursor', function()
    it('should return default cursor when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      eq({ 1, 1 }, component:get_cursor())
    end)

    it('should return real cursor when element is valid', function()
      local component = create_diff_component({ lnum = 5 })

      local cursor = component:get_cursor()
      eq(5, cursor[1])
    end)
  end)

  describe('forward', function()
    it('should delegate place_extmark_text to element when valid', function()
      local called_with = nil
      local component = create_diff_component({ lnum = 1 })
      local orig = component._element.place_extmark_text
      component._element.place_extmark_text = function(self_el, opts)
        called_with = opts
        return 42
      end

      local result = component:place_extmark_text({ row = 0, text = 'hi' })
      eq(42, result)
      eq({ row = 0, text = 'hi' }, called_with)
    end)

    it('should return nil for place_extmark_text when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      local result = component:place_extmark_text({ row = 0 })
      assert.is_nil(result)
    end)

    it('should return nil for place_extmark_sign when element is invalid', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local instance = {
        props = {},
        state = { lines = {}, line_numbers = {}, lines_changes = {}, folds = {}, marks = {}, hunks = {} },
        _mounted = false,
        _needs_update = false,
        _element = {
          is_valid = function()
            return false
          end,
        },
      }
      setmetatable(instance, DiffComponent)

      local result = instance:place_extmark_sign({ col = 0 })
      assert.is_nil(result)
    end)

    it('should delegate set_filetype to element', function()
      local called_with = nil
      local component = create_diff_component({})
      component._element.set_filetype = function(_, ft)
        called_with = ft
      end

      component:set_filetype('lua')
      eq('lua', called_with)
    end)
  end)

  describe('build_diff_render_state data pipeline', function()
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')
    local invariants = require('tests.helpers.diff_invariants')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines or {}) do
        hunk:push(line)
      end
      return hunk
    end

    local function make_unified_diff(hunks, lines)
      return Diff():generate_unified(hunks, lines)
    end

    it('should pass through marks, lines, and hunks from unified Diff', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = make_unified_diff({ hunk }, { 'a', 'new', 'c' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      eq(diff.lines, state.lines)
      eq(diff.marks, state.marks)
      eq(diff.hunks, state.hunks)
    end)

    it('should produce line_numbers with same length as diff.lines', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = make_unified_diff({ hunk }, { 'new1', 'new2' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      eq(#diff.lines, #state.line_numbers)
    end)

    it('should produce lines_changes with same length as diff.lines', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = make_unified_diff({ hunk }, { 'a', 'new', 'c' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      eq(#diff.lines, #state.lines_changes)
    end)

    it('should produce lines_changes with {line_number, lnum_change} shape', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = make_unified_diff({ hunk }, { 'a', 'new', 'c' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      for i, lc in ipairs(state.lines_changes) do
        -- line_number is always present (string)
        assert.is_not_nil(lc.line_number, string.format('lines_changes[%d] missing line_number', i))
        -- lnum_change is nil for context lines, present for changed lines
      end
      -- At least some entries should have non-nil lnum_change
      local has_change = false
      for _, lc in ipairs(state.lines_changes) do
        if lc.lnum_change then has_change = true end
      end
      assert.is_true(has_change)
    end)

    it('should assign correct highlight groups to line_numbers', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = make_unified_diff({ hunk }, { 'a', 'new', 'c' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      local hl_groups = {}
      for _, ln in ipairs(state.line_numbers) do
        hl_groups[ln[2]] = true
      end
      -- Should have at least context and change highlights
      assert.is_true(
        hl_groups['GitLineNr'] ~= nil or hl_groups['GitSignsAdd'] ~= nil or hl_groups['GitSignsDelete'] ~= nil
      )
    end)

    it('should return empty state when diff is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(nil)

      eq({}, state.lines)
      eq({}, state.marks)
      eq({}, state.hunks)
      eq({}, state.line_numbers)
      eq({}, state.lines_changes)
      eq({}, state.folds)
    end)

    it('should preserve marks from Diff through build_diff_render_state', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -2,1 +3,1 @@', { '-old', '+new' })
      local diff = make_unified_diff({ hunk1, hunk2 }, { 'added', 'a', 'new' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      invariants.assert_marks_ascending(state.marks)
      invariants.assert_marks_within_bounds(state.marks, #state.lines)
    end)

    it('should produce folds for unified diff with distant hunks', function()
      -- FoldCalculator requires line_count >= 28 and gap >= 10 between hunks
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -35,1 +36,1 @@', { '-old', '+new' })
      local lines = {}
      for i = 1, 40 do
        lines[i] = 'line' .. i
      end
      lines[1] = 'added'
      lines[36] = 'new'
      local diff = make_unified_diff({ hunk1, hunk2 }, lines)

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      assert.is_true(#state.folds > 0, 'should produce folds for distant hunks')
    end)

    it('should handle diff with no hunks gracefully', function()
      local diff = make_unified_diff({}, { 'a', 'b', 'c' })

      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      local state = component:build_diff_render_state(diff)

      eq({}, state.marks)
      eq({}, state.hunks)
      eq(#diff.lines, #state.line_numbers)
      eq(#diff.lines, #state.lines_changes)
    end)
  end)

  describe('with_element', function()
    it('should return state lines when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})
      component.state.lines = { 'a', 'b' }

      eq({ 'a', 'b' }, component:get_lines())
    end)

    it('should return 0 for get_line_count when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      eq(0, component:get_line_count())
    end)

    it('should return empty string for get_filetype when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      eq('', component:get_filetype())
    end)

    it('should return self for chaining on void methods when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      eq(component, component:set_cursor({ 1, 0 }))
      eq(component, component:enable_cursorline())
      eq(component, component:disable_cursorline())
      eq(component, component:clear_extmarks())
    end)

    it('should return false for is_valid when element is nil', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local component = DiffComponent({})

      assert.is_false(component:is_valid())
    end)

    it('should return true for is_valid when element is valid', function()
      local component = create_diff_component({})
      assert.is_truthy(component:is_valid())
    end)

    it('should return real buffer lines when element is valid', function()
      local component = create_diff_component({})
      -- Buffer was populated with 50 empty lines by create_diff_component
      local lines = component:get_lines()
      eq(50, #lines)
    end)

    it('should return real line count when element is valid', function()
      local component = create_diff_component({})
      eq(50, component:get_line_count())
    end)

    it('should return filetype from buffer when element is valid', function()
      local component = create_diff_component({})
      eq('diff', component:get_filetype())
    end)
  end)

  describe('adversarial build_diff_render_state', function()
    local Diff = require('vgit.core.diff.Diff')
    local GitHunk = require('vgit.git.GitHunk')
    local DiffComponent = require('vgit.ui.components.DiffComponent')

    local function make_hunk(header, diff_lines)
      local hunk = GitHunk(header)
      for _, line in ipairs(diff_lines) do
        hunk:push(line)
      end
      return hunk
    end

    it('change with 10 removes and 1 add should have correct line count', function()
      local diff_lines = {}
      for i = 1, 10 do
        diff_lines[i] = '-old' .. i
      end
      diff_lines[11] = '+survivor'
      local h = make_hunk('@@ -1,1 +1,1 @@', diff_lines)
      local diff = Diff():generate_unified({ h }, { 'survivor' })
      local component = DiffComponent({})

      local state = component:build_diff_render_state(diff)

      eq(#diff.lines, #state.lines)
      eq(#diff.lines, #state.line_numbers)
      eq(#diff.lines, #state.lines_changes)
      -- Should have 10 remove + 1 add lnum_changes
      local change_count = 0
      for _, lc in ipairs(state.lines_changes) do
        if lc.lnum_change then change_count = change_count + 1 end
      end
      eq(11, change_count)
    end)

    it('3 back-to-back change hunks should produce 3 marks with correct navigation', function()
      local h1 = make_hunk('@@ -1,1 +1,1 @@', { '-a', '+A' })
      local h2 = make_hunk('@@ -2,1 +2,1 @@', { '-b', '+B' })
      local h3 = make_hunk('@@ -3,1 +3,1 @@', { '-c', '+C' })
      local diff = Diff():generate_unified({ h1, h2, h3 }, { 'A', 'B', 'C' })
      local component = DiffComponent({})

      local state = component:build_diff_render_state(diff)

      eq(3, #state.marks)
      eq(diff.marks, state.marks)
      -- All marks ascending
      for i = 2, #state.marks do
        assert.is_true(state.marks[i].top > state.marks[i - 1].bot)
      end
    end)

    it('remove at end of file should have marks within line_numbers bounds', function()
      local h = make_hunk('@@ -4,2 +3,0 @@', { '-x', '-y' })
      local diff = Diff():generate_unified({ h }, { 'a', 'b', 'c' })
      local component = DiffComponent({})

      local state = component:build_diff_render_state(diff)

      eq(#diff.lines, #state.line_numbers)
      for _, mark in ipairs(state.marks) do
        assert.is_true(mark.top >= 1)
        assert.is_true(mark.bot <= #state.lines)
      end
    end)

    it('add-change-remove cascade should produce valid state', function()
      local h1 = make_hunk('@@ -0,0 +1,1 @@', { '+header' })
      local h2 = make_hunk('@@ -2,1 +3,1 @@', { '-old', '+new' })
      local h3 = make_hunk('@@ -4,1 +4,0 @@', { '-tail' })
      local diff = Diff():generate_unified({ h1, h2, h3 }, { 'header', 'a', 'new', 'b' })
      local component = DiffComponent({})

      local state = component:build_diff_render_state(diff)

      eq(#diff.lines, #state.lines)
      eq(3, #state.marks)
      -- Verify line_numbers contains exactly #lines entries
      eq(#state.lines, #state.line_numbers)
    end)

    it('very large diff with 20 hunks should produce complete state', function()
      local hunks = {}
      local current = {}
      for i = 1, 40 do
        current[i] = 'line' .. i
      end
      for i = 1, 20 do
        local pos = i * 2
        hunks[i] = make_hunk(string.format('@@ -%d,1 +%d,1 @@', pos, pos), { '-old' .. i, '+line' .. pos })
      end
      local diff = Diff():generate_unified(hunks, current)
      local component = DiffComponent({})

      local state = component:build_diff_render_state(diff)

      eq(20, #state.marks)
      eq(#diff.lines, #state.lines)
      eq(#diff.lines, #state.line_numbers)
      -- Every mark must be within line bounds
      for _, mark in ipairs(state.marks) do
        assert.is_true(mark.top >= 1)
        assert.is_true(mark.bot <= #state.lines)
      end
    end)

    it('nil diff should return empty state without crashing', function()
      local component = DiffComponent({})
      local state = component:build_diff_render_state(nil)

      -- Should gracefully return empty state, not crash
      assert.is_not_nil(state)
      eq({}, state.lines)
      eq({}, state.marks)
      eq({}, state.hunks)
      eq({}, state.lines_changes)
      eq({}, state.line_numbers)
    end)
  end)
end)
