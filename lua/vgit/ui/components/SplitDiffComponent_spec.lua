local eq = assert.are.same

local function create_split_component(overrides)
  local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')
  local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')

  local instance = {
    props = overrides.props or {},
    state = overrides.state or { previous_lines = {}, current_lines = {} },
    mounted = false,
    _needs_update = false,
    _previous_component = nil,
    _current_component = nil,
    _line_number_calculator = LineNumberCalculator(),
  }

  setmetatable(instance, SplitDiffComponent)
  return instance
end

describe('SplitDiffComponent:', function()
  describe('calculate_split_line_numbers', function()
    it('should separate lnum_changes by buftype', function()
      local component = create_split_component({})
      local diff = {
        lines = { 'line1', 'line2', 'line3' },
        current_lines = { 'line1', 'line2', 'line3' },
        previous_lines = { 'line1', 'line2', 'line3' },
        marks = {},
        lnum_changes = {
          { buftype = 'current', lnum = 1, type = 'add' },
          { buftype = 'previous', lnum = 1, type = 'remove' },
          { buftype = 'current', lnum = 2, type = 'void' },
          { buftype = 'previous', lnum = 2, type = 'void' },
        },
      }

      local result = component:calculate_split_line_numbers(diff)

      assert.is_not_nil(result.previous)
      assert.is_not_nil(result.current)
      assert.is_not_nil(result.previous.lines)
      assert.is_not_nil(result.previous.changes)
      assert.is_not_nil(result.current.lines)
      assert.is_not_nil(result.current.changes)
    end)

    it('should handle empty lnum_changes', function()
      local component = create_split_component({})
      local diff = {
        lines = {},
        current_lines = {},
        previous_lines = {},
        marks = {},
        lnum_changes = {},
      }

      local result = component:calculate_split_line_numbers(diff)

      assert.is_not_nil(result.previous)
      assert.is_not_nil(result.current)
    end)
  end)

  describe('should_component_update', function()
    it('should return true when diff changes', function()
      local diff_ref = { lines = {} }
      local component = create_split_component({
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
      local component = create_split_component({
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
      local component = create_split_component({
        props = { diff = diff_ref, filetype = 'lua' },
      })

      local result = component:should_component_update({
        diff = diff_ref,
        filetype = 'lua',
      }, {})
      assert.is_false(result)
    end)
  end)

end)
