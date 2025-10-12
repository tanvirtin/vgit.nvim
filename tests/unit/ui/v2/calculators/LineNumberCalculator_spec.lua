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

    it('should handle multiple consecutive void lines', function()
      local diff = {
        previous_lines = {
          ' line 1',
          ' line 2',
          ' line 3',
          ' line 4',
        },
        current_lines = {
          ' line 1',
          '+new 1',
          '+new 2',
          ' line 2',
        },
        lnum_changes = {
          { lnum = 1, type = 'context', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
          { lnum = 3, type = 'add', buftype = 'current' },
          { lnum = 4, type = 'context', buftype = 'current' },
          { lnum = 1, type = 'context', buftype = 'previous' },
          { lnum = 2, type = 'void', buftype = 'previous' },
          { lnum = 3, type = 'void', buftype = 'previous' },
          { lnum = 4, type = 'context', buftype = 'previous' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      -- Void lines consume line numbers to maintain alignment
      assert.equals(4, #result.previous.lines)
      assert.equals('1 ', result.previous.lines[1][1])
      assert.equals('⣿', result.previous.lines[2][1])
      assert.equals('⣿', result.previous.lines[3][1])
      assert.equals('2 ', result.previous.lines[4][1]) -- Line 2 of actual content (after voids)
    end)

    it('should handle mixed add/remove in split diff', function()
      local diff = {
        previous_lines = {
          ' line 1',
          '-removed',
          ' line 2',
        },
        current_lines = {
          ' line 1',
          '+added',
          ' line 2',
        },
        lnum_changes = {
          { lnum = 1, type = 'context', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
          { lnum = 3, type = 'context', buftype = 'current' },
          { lnum = 1, type = 'context', buftype = 'previous' },
          { lnum = 2, type = 'remove', buftype = 'previous' },
          { lnum = 3, type = 'context', buftype = 'previous' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      assert.equals('1 ', result.previous.lines[1][1])
      assert.equals('GitLineNr', result.previous.lines[1][2])
      assert.equals('2 ', result.previous.lines[2][1])
      assert.equals('GitSignsDelete', result.previous.lines[2][2])
      assert.equals('3 ', result.previous.lines[3][1])

      assert.equals('1 ', result.current.lines[1][1])
      assert.equals('GitLineNr', result.current.lines[1][2])
      assert.equals('2 ', result.current.lines[2][1])
      assert.equals('GitSignsAdd', result.current.lines[2][2])
      assert.equals('3 ', result.current.lines[3][1])
    end)

    it('should handle empty diff', function()
      local diff = {
        previous_lines = {},
        current_lines = {},
        lnum_changes = {},
      }

      local result = calculator:calculate_split_line_numbers(diff)

      assert.equals(0, #result.previous.lines)
      assert.equals(0, #result.current.lines)
    end)

    it('should handle only additions in current', function()
      local diff = {
        previous_lines = {},
        current_lines = {
          '+line 1',
          '+line 2',
          '+line 3',
        },
        lnum_changes = {
          { lnum = 1, type = 'add', buftype = 'current' },
          { lnum = 2, type = 'add', buftype = 'current' },
          { lnum = 3, type = 'add', buftype = 'current' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      assert.equals(3, #result.current.lines)
      for i = 1, 3 do
        assert.equals(i .. ' ', result.current.lines[i][1])
        assert.equals('GitSignsAdd', result.current.lines[i][2])
      end
    end)

    it('should handle only removals in previous', function()
      local diff = {
        previous_lines = {
          '-line 1',
          '-line 2',
          '-line 3',
        },
        current_lines = {},
        lnum_changes = {
          { lnum = 1, type = 'remove', buftype = 'previous' },
          { lnum = 2, type = 'remove', buftype = 'previous' },
          { lnum = 3, type = 'remove', buftype = 'previous' },
        },
      }

      local result = calculator:calculate_split_line_numbers(diff)

      assert.equals(3, #result.previous.lines)
      for i = 1, 3 do
        assert.equals(i .. ' ', result.previous.lines[i][1])
        assert.equals('GitSignsDelete', result.previous.lines[i][2])
      end
    end)
  end)

  describe('calculate_unified_line_numbers edge cases', function()
    it('should handle empty diff', function()
      local diff = {
        lines = {},
        lnum_changes = {},
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(0, #lines)
      assert.equals(0, #lines_changes)
    end)

    it('should handle consecutive removals', function()
      local diff = {
        lines = {
          ' context',
          '-removed 1',
          '-removed 2',
          '-removed 3',
          ' context',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'remove' },
          { lnum = 3, type = 'remove' },
          { lnum = 4, type = 'remove' },
          { lnum = 5, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(5, #lines)
      assert.equals('1 ', lines[1][1])
      assert.equals('  ', lines[2][1])
      assert.equals('  ', lines[3][1])
      assert.equals('  ', lines[4][1])
      assert.equals('2 ', lines[5][1])
    end)

    it('should handle consecutive additions', function()
      local diff = {
        lines = {
          ' context',
          '+added 1',
          '+added 2',
          '+added 3',
          ' context',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'add' },
          { lnum = 3, type = 'add' },
          { lnum = 4, type = 'add' },
          { lnum = 5, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(5, #lines)
      assert.equals('1 ', lines[1][1])
      assert.equals('2 ', lines[2][1])
      assert.equals('3 ', lines[3][1])
      assert.equals('4 ', lines[4][1])
      assert.equals('5 ', lines[5][1])
    end)

    it('should handle alternating add/remove', function()
      local diff = {
        lines = {
          '-old 1',
          '+new 1',
          '-old 2',
          '+new 2',
        },
        lnum_changes = {
          { lnum = 1, type = 'remove' },
          { lnum = 2, type = 'add' },
          { lnum = 3, type = 'remove' },
          { lnum = 4, type = 'add' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      assert.equals(4, #lines)
      assert.equals('  ', lines[1][1])
      assert.equals('1 ', lines[2][1])
      assert.equals('  ', lines[3][1])
      assert.equals('2 ', lines[4][1])
    end)
  end)
end)
