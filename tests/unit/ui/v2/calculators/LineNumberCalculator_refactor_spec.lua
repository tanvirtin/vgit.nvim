local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')

describe('LineNumberCalculator Refactor Tests', function()
  local calculator

  before_each(function()
    calculator = LineNumberCalculator()
  end)

  describe('Common line number calculation logic', function()
    it('should extract common logic for unified line numbers', function()
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

      -- Test that the refactored method produces same results
      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      -- Verify the structure and content match expected behavior
      assert.equals(5, #lines)
      assert.equals(5, #lines_changes)

      -- Verify line numbers and highlights
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

    it('should extract common logic for split current line numbers', function()
      local diff = {
        current_lines = {
          ' old line 1',
          '+new line 1',
          ' old line 2',
          '+new line 2',
          ' old line 3',
        },
      }
      local lnum_change_map = {
        [1] = { lnum = 1, type = 'context' },
        [2] = { lnum = 2, type = 'add' },
        [3] = { lnum = 3, type = 'context' },
        [4] = { lnum = 4, type = 'add' },
        [5] = { lnum = 5, type = 'context' },
      }

      local lines, lines_changes = calculator:calculate_split_current_line_numbers(diff, lnum_change_map)

      assert.equals(5, #lines)
      assert.equals(5, #lines_changes)

      -- Should produce same results as unified
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

    it('should extract common logic for split previous line numbers', function()
      local diff = {
        previous_lines = {
          ' old line 1',
          '-removed line 1',
          ' old line 2',
          '-removed line 2',
          ' old line 3',
        },
      }
      local lnum_change_map = {
        [1] = { lnum = 1, type = 'context' },
        [2] = { lnum = 2, type = 'remove' },
        [3] = { lnum = 3, type = 'context' },
        [4] = { lnum = 4, type = 'remove' },
        [5] = { lnum = 5, type = 'context' },
      }

      local lines, lines_changes = calculator:calculate_split_previous_line_numbers(diff, lnum_change_map)

      assert.equals(5, #lines)
      assert.equals(5, #lines_changes)

      -- Should produce same results as unified
      assert.equals('1 ', lines[1][1])
      assert.equals('GitLineNr', lines[1][2])
      assert.equals('2 ', lines[2][1])
      assert.equals('GitSignsDelete', lines[2][2])
      assert.equals('3 ', lines[3][1])
      assert.equals('GitLineNr', lines[3][2])
      assert.equals('4 ', lines[4][1])
      assert.equals('GitSignsDelete', lines[4][2])
      assert.equals('5 ', lines[5][1])
      assert.equals('GitLineNr', lines[5][2])
    end)

    it('should handle void lines consistently across all methods', function()
      local diff = {
        previous_lines = {
          ' line 1',
          ' line 2',
          ' line 3',
        },
        current_lines = {
          ' line 1',
          '+new line',
          ' line 2',
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

      -- Previous should have void line
      assert.equals(3, #result.previous.lines)
      assert.equals('1 ', result.previous.lines[1][1])
      assert.equals('GitLineNr', result.previous.lines[1][2])
      assert.equals('⣿', result.previous.lines[2][1]) -- void symbol
      assert.equals('GitLineNr', result.previous.lines[2][2])
      assert.equals('2 ', result.previous.lines[3][1])
      assert.equals('GitLineNr', result.previous.lines[3][2])

      -- Current should have normal lines
      assert.equals(3, #result.current.lines)
      assert.equals('1 ', result.current.lines[1][1])
      assert.equals('GitLineNr', result.current.lines[1][2])
      assert.equals('2 ', result.current.lines[2][1])
      assert.equals('GitSignsAdd', result.current.lines[2][2])
      assert.equals('3 ', result.current.lines[3][1])
      assert.equals('GitLineNr', result.current.lines[3][2])
    end)

    it('should handle edge cases consistently', function()
      -- Empty diff
      local empty_diff = {
        lines = {},
        lnum_changes = {},
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(empty_diff)
      assert.equals(0, #lines)
      assert.equals(0, #lines_changes)

      -- Empty split diff
      local empty_split_diff = {
        previous_lines = {},
        current_lines = {},
        lnum_changes = {},
      }

      local result = calculator:calculate_split_line_numbers(empty_split_diff)
      assert.equals(0, #result.previous.lines)
      assert.equals(0, #result.current.lines)
    end)

    it('should maintain line number continuity', function()
      local diff = {
        lines = {
          ' context 1',
          '+add 1',
          '+add 2',
          ' context 2',
          '-remove 1',
          ' context 3',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'add' },
          { lnum = 3, type = 'add' },
          { lnum = 4, type = 'context' },
          { lnum = 5, type = 'remove' },
          { lnum = 6, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(diff)

      -- Line numbers should be continuous: 1, 2, 3, 4, 5, 6
      assert.equals('1 ', lines[1][1])
      assert.equals('2 ', lines[2][1])
      assert.equals('3 ', lines[3][1])
      assert.equals('4 ', lines[4][1])
      assert.equals('  ', lines[5][1]) -- removed line shows as spaces
      assert.equals('5 ', lines[6][1])
    end)
  end)

  describe('Refactored method behavior verification', function()
    it('should produce identical results before and after refactoring', function()
      local test_cases = {
        {
          name = 'unified with mixed changes',
          diff = {
            lines = { ' line 1', '+add', ' line 2', '-remove', ' line 3' },
            lnum_changes = {
              { lnum = 1, type = 'context' },
              { lnum = 2, type = 'add' },
              { lnum = 3, type = 'context' },
              { lnum = 4, type = 'remove' },
              { lnum = 5, type = 'context' },
            },
          },
          method = 'calculate_unified_line_numbers',
        },
        {
          name = 'split with void lines',
          diff = {
            previous_lines = { ' line 1', ' line 2' },
            current_lines = { ' line 1', '+add', ' line 2' },
            lnum_changes = {
              { lnum = 1, type = 'context', buftype = 'current' },
              { lnum = 2, type = 'add', buftype = 'current' },
              { lnum = 3, type = 'context', buftype = 'current' },
              { lnum = 1, type = 'context', buftype = 'previous' },
              { lnum = 2, type = 'void', buftype = 'previous' },
              { lnum = 3, type = 'context', buftype = 'previous' },
            },
          },
          method = 'calculate_split_line_numbers',
        },
      }

      for _, test_case in ipairs(test_cases) do
        if test_case.method == 'calculate_unified_line_numbers' then
          local lines, lines_changes = calculator[test_case.method](calculator, test_case.diff)

          -- Verify structure
          assert.equals(#test_case.diff.lines, #lines)
          assert.equals(#test_case.diff.lines, #lines_changes)

          -- Verify each line has proper format
          for i = 1, #lines do
            assert.is_table(lines[i])
            assert.equals(2, #lines[i])
            assert.is_string(lines[i][1]) -- line text
            assert.is_string(lines[i][2]) -- highlight group
          end
        elseif test_case.method == 'calculate_split_line_numbers' then
          local result = calculator[test_case.method](calculator, test_case.diff)

          -- Verify structure
          assert.is_table(result.previous)
          assert.is_table(result.current)
          assert.is_table(result.previous.lines)
          assert.is_table(result.previous.changes)
          assert.is_table(result.current.lines)
          assert.is_table(result.current.changes)

          -- Verify line counts match
          assert.equals(#test_case.diff.previous_lines, #result.previous.lines)
          assert.equals(#test_case.diff.current_lines, #result.current.lines)
        end
      end
    end)

    it('should handle complex scenarios with multiple change types', function()
      local complex_diff = {
        lines = {
          ' context 1',
          '+add 1',
          '+add 2',
          ' context 2',
          '-remove 1',
          '-remove 2',
          ' context 3',
          '+add 3',
          ' context 4',
        },
        lnum_changes = {
          { lnum = 1, type = 'context' },
          { lnum = 2, type = 'add' },
          { lnum = 3, type = 'add' },
          { lnum = 4, type = 'context' },
          { lnum = 5, type = 'remove' },
          { lnum = 6, type = 'remove' },
          { lnum = 7, type = 'context' },
          { lnum = 8, type = 'add' },
          { lnum = 9, type = 'context' },
        },
      }

      local lines, lines_changes = calculator:calculate_unified_line_numbers(complex_diff)

      -- Should have 9 lines total
      assert.equals(9, #lines)
      assert.equals(9, #lines_changes)

      -- Verify line numbers are sequential
      local expected_line_numbers = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
      local actual_line_numbers = {}
      for i = 1, #lines do
        if lines[i][1] ~= '  ' then -- not a removed line
          local line_num = tonumber(lines[i][1]:match('(%d+)'))
          if line_num then table.insert(actual_line_numbers, line_num) end
        end
      end

      assert.equals(7, #actual_line_numbers)
      for i = 1, #actual_line_numbers do
        assert.equals(i, actual_line_numbers[i])
      end
    end)
  end)
end)
