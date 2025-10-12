local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')

describe('LineNumberCalculator', function()
  local calculator

  before_each(function()
    calculator = LineNumberCalculator()
  end)

  describe('calculate_unified_line_numbers', function()
    it('should calculate correct line numbers for unified diff', function()
      local diff = {
        lines = {
          ' old line 1',
          '+new line 1',
          ' old line 2',
          '+new line 2',
          ' old line 3',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'add' },
          { lnum = 3, type = 'context' },
          { lnum = 4, type = 'add' },
          { lnum = 5, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(5, #lines)
      assert.equals(5, #lines_changes)

      assert.equals('1 ', lines[1][1])
      assert.equals('GitLineNr', lines[1][2])

      assert.equals('2 ', lines[2][1])
      assert.equals('GitSignsAdd', lines[2][2])

      assert.equals('3 ', lines[3][1])
      assert.equals('GitLineNr', lines[3][2])

      assert.equals('4 ', lines[4][1])
      assert.equals('GitSignsAdd', lines[4][2])

      assert.equals('5 ', lines[5][1])
      assert.equals('GitLineNr', lines[5][2])
    end)

    it('should handle removed lines correctly', function()
      local diff = {
        lines = {
          ' old line 1',
          '-removed line',
          ' old line 2',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'remove' },
          { lnum = 3, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(3, #lines)

      assert.equals('1 ', lines[1][1])
      assert.equals('GitLineNr', lines[1][2])

      assert.equals('  ', lines[2][1])
      assert.equals('GitSignsDelete', lines[2][2])

      assert.equals('2 ', lines[3][1])
      assert.equals('GitLineNr', lines[3][2])
    end)
  end)

  describe('calculate_split_line_numbers', function()
    it('should calculate correct line numbers for split diff', function()
      local diff = {
        previous_lines = {
          ' old line 1',
          ' old line 2',
          ' old line 3',
        },
        current_lines = {
          ' old line 1',
          '+new line 1',
          ' old line 2',
          '+new line 2',
          ' old line 3',
        },
        lnum_changes = {
          { lnum = 1, type = 'context', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
          { lnum = 3, type = 'context', buftype = 'current' },
          { lnum = 4, type = 'add', buftype = 'current' },
          { lnum = 5, type = 'context', buftype = 'current' },
          { lnum = 1, type = 'context', buftype = 'previous' },
          { lnum = 2, type = 'context', buftype = 'previous' },
          { lnum = 3, type = 'context', buftype = 'previous' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      assert.equals(3, #result.previous.lines)
      for i = 1, 3 do
        assert.equals(string.format('%d ', i), result.previous.lines[i][1])
        assert.equals('GitLineNr', result.previous.lines[i][2])
      end

      assert.equals(5, #result.current.lines)
      assert.equals('1 ', result.current.lines[1][1])
      assert.equals('GitLineNr', result.current.lines[1][2])
      assert.equals('2 ', result.current.lines[2][1])
      assert.equals('GitSignsAdd', result.current.lines[2][2])
      assert.equals('3 ', result.current.lines[3][1])
      assert.equals('GitLineNr', result.current.lines[3][2])
      assert.equals('4 ', result.current.lines[4][1])
      assert.equals('GitSignsAdd', result.current.lines[4][2])
      assert.equals('5 ', result.current.lines[5][1])
      assert.equals('GitLineNr', result.current.lines[5][2])
    end)

    it('should handle void lines in split diff', function()
      local diff = {
        previous_lines = {
          ' old line 1',
          ' old line 2',
          ' old line 3',
        },
        current_lines = {
          ' old line 1',
          '+new line 1',
          ' old line 2',
        },
        lnum_changes = {
          { lnum = 1, type = 'context', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
          { lnum = 3, type = 'context', buftype = 'current' },
          { lnum = 1, type = 'context', buftype = 'previous' },
          { lnum = 2, type = 'void', buftype = 'previous' },
          { lnum = 3, type = 'context', buftype = 'previous' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      -- Void lines are UI placeholders and consume line positions to maintain alignment
      assert.equals(3, #result.previous.lines)
      assert.equals('1 ', result.previous.lines[1][1])
      assert.equals('GitLineNr', result.previous.lines[1][2])
      assert.equals('⣿', result.previous.lines[2][1])
      assert.equals('GitLineNr', result.previous.lines[2][2])
      assert.equals('2 ', result.previous.lines[3][1]) -- Next actual line number after void
      assert.equals('GitLineNr', result.previous.lines[3][2])
    end)
  end)
end)
