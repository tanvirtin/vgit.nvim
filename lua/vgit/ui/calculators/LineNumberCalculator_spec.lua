local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')
local symbols_setting = require('vgit.settings.symbols')

local eq = assert.are.same

describe('LineNumberCalculator:', function()
  local calc

  before_each(function()
    calc = LineNumberCalculator()
  end)

  describe('_calculate_line_numbers', function()
    it('should produce numbered lines for normal lines', function()
      local lines = { 'a', 'b', 'c' }
      local lnum_change_map = {}
      local result, changes = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(3, #result)
      assert.are.equal('1 ', result[1][1])
      assert.are.equal('GitLineNr', result[1][2])
      assert.are.equal('2 ', result[2][1])
      assert.are.equal('3 ', result[3][1])
    end)

    it('should use void symbol for void entries', function()
      local void_symbol = symbols_setting:get('void')
      local lines = { 'a', '', 'c' }
      local lnum_change_map = {
        [2] = { type = 'void' },
      }
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(3, #result)
      assert.are.equal('1 ', result[1][1])
      -- Void line should use the void symbol repeated
      assert.truthy(result[2][1]:match(vim.pesc(void_symbol)))
      assert.are.equal('GitLineNr', result[2][2])
      -- Line count should NOT increment for void
      assert.are.equal('2 ', result[3][1])
    end)

    it('should highlight add entries with GitSignsAdd', function()
      local lines = { 'a', 'new' }
      local lnum_change_map = {
        [2] = { type = 'add' },
      }
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('GitLineNr', result[1][2])
      assert.are.equal('GitSignsAdd', result[2][2])
    end)

    it('should highlight remove entries with GitSignsDelete', function()
      local lines = { 'a', 'removed' }
      local lnum_change_map = {
        [2] = { type = 'remove' },
      }
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('GitSignsDelete', result[2][2])
    end)

    it('should increment line count for add and remove entries', function()
      local lines = { 'a', 'b', 'c' }
      local lnum_change_map = {
        [2] = { type = 'add' },
      }
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('1 ', result[1][1])
      assert.are.equal('2 ', result[2][1])
      assert.are.equal('3 ', result[3][1])
    end)

    it('should not increment line count for void entries', function()
      local lines = { 'a', '', 'c', 'd' }
      local lnum_change_map = {
        [2] = { type = 'void' },
      }
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('1 ', result[1][1])
      -- void does not increment
      assert.are.equal('2 ', result[3][1])
      assert.are.equal('3 ', result[4][1])
    end)

    it('should return changes array parallel to lines', function()
      local lines = { 'a', 'b' }
      local lnum_change_map = {
        [1] = { type = 'add' },
      }
      local _, changes = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(2, #changes)
      assert.is_not_nil(changes[1].line_number)
      assert.is_not_nil(changes[1].lnum_change)
      assert.is_nil(changes[2].lnum_change)
    end)

    it('should handle empty lines', function()
      local lines = {}
      local lnum_change_map = {}
      local result = calc:_calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(0, #result)
    end)

    it('should start from custom line_count_start', function()
      local lines = { 'a', 'b' }
      local lnum_change_map = {}
      local result = calc:_calculate_line_numbers(lines, lnum_change_map, 10)

      assert.are.equal('10 ', result[1][1])
      assert.are.equal('11 ', result[2][1])
    end)
  end)

  describe('calculate_unified_line_numbers', function()
    it('should produce blank for remove lines', function()
      local diff = {
        lines = { 'a', 'removed', 'b' },
        lnum_changes = {
          { lnum = 2, type = 'remove', buftype = 'current' },
        },
      }
      local result = calc:calculate_unified_line_numbers(diff)

      assert.are.equal(3, #result)
      assert.are.equal('1 ', result[1][1])
      assert.are.equal('  ', result[2][1])
      assert.are.equal('GitSignsDelete', result[2][2])
      assert.are.equal('2 ', result[3][1])
    end)

    it('should increment counter for add lines', function()
      local diff = {
        lines = { 'a', 'added', 'b' },
        lnum_changes = {
          { lnum = 2, type = 'add', buftype = 'current' },
        },
      }
      local result = calc:calculate_unified_line_numbers(diff)

      assert.are.equal('1 ', result[1][1])
      assert.are.equal('2 ', result[2][1])
      assert.are.equal('GitSignsAdd', result[2][2])
      assert.are.equal('3 ', result[3][1])
    end)

    it('should handle mixed add and remove', function()
      local diff = {
        lines = { 'removed', 'added', 'normal' },
        lnum_changes = {
          { lnum = 1, type = 'remove', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
        },
      }
      local result = calc:calculate_unified_line_numbers(diff)

      assert.are.equal('  ', result[1][1])
      assert.are.equal('1 ', result[2][1])
      assert.are.equal('2 ', result[3][1])
    end)

    it('should handle empty diff', function()
      local diff = { lines = {}, lnum_changes = {} }
      local result, changes = calc:calculate_unified_line_numbers(diff)

      assert.are.equal(0, #result)
      assert.are.equal(0, #changes)
    end)

    it('should return changes array with lnum_change info', function()
      local diff = {
        lines = { 'a', 'b' },
        lnum_changes = {
          { lnum = 1, type = 'add', buftype = 'current' },
        },
      }
      local _, changes = calc:calculate_unified_line_numbers(diff)

      assert.are.equal(2, #changes)
      assert.is_not_nil(changes[1].lnum_change)
      assert.are.equal('add', changes[1].lnum_change.type)
      assert.is_nil(changes[2].lnum_change)
    end)
  end)

  describe('calculate_split_line_numbers', function()
    it('should partition lnum_changes by buftype', function()
      local diff = {
        current_lines = { 'new1', 'b' },
        previous_lines = { '', 'b' },
        lnum_changes = {
          { lnum = 1, type = 'add', buftype = 'current' },
          { lnum = 1, type = 'void', buftype = 'previous' },
        },
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.is_not_nil(result.current)
      assert.is_not_nil(result.previous)
      assert.are.equal(2, #result.current.lines)
      assert.are.equal(2, #result.previous.lines)
    end)

    it('should use GitSignsAdd for current add entries', function()
      local diff = {
        current_lines = { 'new' },
        previous_lines = { '' },
        lnum_changes = {
          { lnum = 1, type = 'add', buftype = 'current' },
          { lnum = 1, type = 'void', buftype = 'previous' },
        },
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.are.equal('GitSignsAdd', result.current.lines[1][2])
    end)

    it('should use void symbol for previous void entries', function()
      local void_symbol = symbols_setting:get('void')
      local diff = {
        current_lines = { 'new' },
        previous_lines = { '' },
        lnum_changes = {
          { lnum = 1, type = 'add', buftype = 'current' },
          { lnum = 1, type = 'void', buftype = 'previous' },
        },
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.truthy(result.previous.lines[1][1]:match(vim.pesc(void_symbol)))
    end)

    it('should handle remove in previous side', function()
      local diff = {
        current_lines = { '' },
        previous_lines = { 'old' },
        lnum_changes = {
          { lnum = 1, type = 'void', buftype = 'current' },
          { lnum = 1, type = 'remove', buftype = 'previous' },
        },
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.are.equal('GitSignsDelete', result.previous.lines[1][2])
    end)

    it('should handle empty diff', function()
      local diff = {
        current_lines = {},
        previous_lines = {},
        lnum_changes = {},
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.are.equal(0, #result.current.lines)
      assert.are.equal(0, #result.previous.lines)
    end)

    it('should return changes for both sides', function()
      local diff = {
        current_lines = { 'a' },
        previous_lines = { 'a' },
        lnum_changes = {},
      }
      local result = calc:calculate_split_line_numbers(diff)

      assert.are.equal(1, #result.current.changes)
      assert.are.equal(1, #result.previous.changes)
    end)
  end)
end)
