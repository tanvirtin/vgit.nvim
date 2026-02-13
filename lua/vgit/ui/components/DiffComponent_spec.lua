local eq = assert.are.same

-- Create a minimal DiffComponent with mocked _element for testing
-- pure logic methods without requiring Neovim UI
local function create_diff_component(overrides)
  local DiffComponent = require('vgit.ui.components.DiffComponent')

  local current_lnum = overrides.lnum or 1
  local instance = {
    props = overrides.props or {},
    state = overrides.state or {
      lines = {},
      line_numbers = {},
      lines_changes = {},
      folds = {},
      marks = {},
      hunks = {},
    },
    mounted = false,
    _needs_update = false,
    _element = {
      is_valid = function() return true end,
      get_lnum = function() return current_lnum end,
      set_lnum = function(_, lnum)
        current_lnum = lnum
      end,
      position_cursor = function() end,
    },
    _line_number_calculator = require('vgit.ui.calculators.LineNumberCalculator')(),
    _diff_calculator = require('vgit.ui.calculators.DiffCalculator')(),
    _fold_calculator = require('vgit.ui.calculators.FoldCalculator')(),
  }

  setmetatable(instance, DiffComponent)
  return instance
end

describe('DiffComponent:', function()
  describe('should_component_update', function()
    it('should return true when diff changes', function()
      local diff_ref = { lines = {} }
      local component = create_diff_component({
        props = { diff = diff_ref, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = { lines = {} },
        filetype = 'lua',
      }, {})
      assert.is_true(result)
    end)

    it('should return true when filetype changes', function()
      local diff_ref = { lines = {} }
      local component = create_diff_component({
        props = { diff = diff_ref, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = diff_ref,
        filetype = 'python',
      }, {})
      assert.is_true(result)
    end)

    it('should return false when nothing changes', function()
      local diff_ref = { lines = {} }
      local component = create_diff_component({
        props = { diff = diff_ref, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = diff_ref,
        filetype = 'lua',
      }, {})
      assert.is_false(result)
    end)
  end)

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
      local instance = {
        props = {},
        state = {},
        mounted = false,
        _needs_update = false,
      }
      setmetatable(instance, DiffComponent)

      local state = instance:get_initial_state()

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

  describe('should_component_update edge cases', function()
    it('should return false when both diff and filetype are same reference', function()
      local diff_ref = { lines = { 'a', 'b' } }
      local component = create_diff_component({
        props = { diff = diff_ref, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = diff_ref,
        filetype = 'lua',
      }, {})
      assert.is_false(result)
    end)

    it('should return true when only diff reference changes', function()
      local diff1 = { lines = {} }
      local diff2 = { lines = {} }
      local component = create_diff_component({
        props = { diff = diff1, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = diff2,
        filetype = 'lua',
      }, {})
      assert.is_true(result)
    end)
  end)

  describe('get_lnum', function()
    it('should return lnum from element', function()
      local component = create_diff_component({ lnum = 42 })
      eq(42, component:get_lnum())
    end)
  end)

  describe('get_cursor', function()
    it('should return default cursor when element has no get_cursor', function()
      local DiffComponent = require('vgit.ui.components.DiffComponent')
      local instance = {
        props = {},
        state = { lines = {}, line_numbers = {}, lines_changes = {}, folds = {}, marks = {}, hunks = {} },
        mounted = false,
        _needs_update = false,
        _element = nil,
      }
      setmetatable(instance, DiffComponent)

      eq({ 1, 1 }, instance:get_cursor())
    end)
  end)

end)
