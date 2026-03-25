local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')
local symbols_setting = require('vgit.settings.symbols')

local eq = assert.are.same

describe('LineNumberCalculator:', function()
  describe('_calculate_line_numbers', function()
    it('should produce numbered lines for normal lines', function()
      local lines = { 'a', 'b', 'c' }
      local lnum_change_map = {}
      local result, changes = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

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
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

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
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('GitLineNr', result[1][2])
      assert.are.equal('GitSignsAdd', result[2][2])
    end)

    it('should highlight remove entries with GitSignsDelete', function()
      local lines = { 'a', 'removed' }
      local lnum_change_map = {
        [2] = { type = 'remove' },
      }
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('GitSignsDelete', result[2][2])
    end)

    it('should increment line count for add and remove entries', function()
      local lines = { 'a', 'b', 'c' }
      local lnum_change_map = {
        [2] = { type = 'add' },
      }
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal('1 ', result[1][1])
      assert.are.equal('2 ', result[2][1])
      assert.are.equal('3 ', result[3][1])
    end)

    it('should not increment line count for void entries', function()
      local lines = { 'a', '', 'c', 'd' }
      local lnum_change_map = {
        [2] = { type = 'void' },
      }
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

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
      local _, changes = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(2, #changes)
      assert.is_not_nil(changes[1].line_number)
      assert.is_not_nil(changes[1].lnum_change)
      assert.is_nil(changes[2].lnum_change)
    end)

    it('should handle empty lines', function()
      local lines = {}
      local lnum_change_map = {}
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map)

      assert.are.equal(0, #result)
    end)

    it('should start from custom line_count_start', function()
      local lines = { 'a', 'b' }
      local lnum_change_map = {}
      local result = LineNumberCalculator._calculate_line_numbers(lines, lnum_change_map, 10)

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
      local result = LineNumberCalculator.calculate_unified_line_numbers(diff)

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
      local result = LineNumberCalculator.calculate_unified_line_numbers(diff)

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
      local result = LineNumberCalculator.calculate_unified_line_numbers(diff)

      assert.are.equal('  ', result[1][1])
      assert.are.equal('1 ', result[2][1])
      assert.are.equal('2 ', result[3][1])
    end)

    it('should handle empty diff', function()
      local diff = { lines = {}, lnum_changes = {} }
      local result, changes = LineNumberCalculator.calculate_unified_line_numbers(diff)

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
      local _, changes = LineNumberCalculator.calculate_unified_line_numbers(diff)

      assert.are.equal(2, #changes)
      assert.is_not_nil(changes[1].lnum_change)
      assert.are.equal('add', changes[1].lnum_change.type)
      assert.is_nil(changes[2].lnum_change)
    end)
  end)
end)
