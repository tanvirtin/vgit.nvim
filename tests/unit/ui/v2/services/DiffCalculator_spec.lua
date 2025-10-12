local DiffCalculator = require('vgit.ui.calculators.DiffCalculator')

describe('DiffCalculator', function()
  local calculator

  before_each(function()
    calculator = DiffCalculator()
  end)

  describe('calculate_line_diff_marks', function()
    it('should calculate correct line diff marks for added lines', function()
      local line_changes = {
        lnum_change = {
          lnum = 2,
          type = 'add',
        },
      }

      local marks = calculator:calculate_line_diff_marks(line_changes)

      assert.is_not_nil(marks)
      assert.is_not_nil(marks.sign)
      assert.equals(1, marks.sign.col) -- lnum - 1
      assert.equals('GitSignsAddLn', marks.sign.name)
    end)

    it('should calculate correct line diff marks for removed lines', function()
      local line_changes = {
        lnum_change = {
          lnum = 3,
          type = 'remove',
        },
      }

      local marks = calculator:calculate_line_diff_marks(line_changes)

      assert.is_not_nil(marks)
      assert.is_not_nil(marks.sign)
      assert.equals(2, marks.sign.col) -- lnum - 1
      assert.equals('GitSignsDeleteLn', marks.sign.name)
    end)

    it('should calculate correct line diff marks for void lines', function()
      local line_changes = {
        lnum_change = {
          lnum = 4,
          type = 'void',
        },
      }

      local marks = calculator:calculate_line_diff_marks(line_changes)

      assert.is_not_nil(marks)
      assert.is_not_nil(marks.void_text)
      assert.equals(3, marks.void_text.row) -- lnum - 1
      assert.equals(0, marks.void_text.col)
      assert.equals('GitLineNr', marks.void_text.hl)
    end)

    it('should return nil for lines without changes', function()
      local line_changes = {
        lnum_change = nil,
      }

      local marks = calculator:calculate_line_diff_marks(line_changes)

      assert.is_nil(marks)
    end)
  end)

  describe('calculate_word_diff_marks', function()
    it('should calculate correct word diff marks for added text', function()
      local line_changes = {
        lnum_change = {
          lnum = 2,
          type = 'add',
          word_diff = {
            { 0, 'unchanged ' },
            { -1, 'added text' },
            { 0, ' more unchanged' },
          },
        },
      }

      local marks = calculator:calculate_word_diff_marks(line_changes, 2)

      assert.is_not_nil(marks)
      assert.equals(1, marks.row) -- lnum - 1
      assert.equals(0, marks.col)
      assert.equals(3, #marks.texts)

      -- Check text segments
      assert.equals('unchanged ', marks.texts[1][1])
      assert.is_nil(marks.texts[1][2]) -- No highlight for unchanged

      assert.equals('added text', marks.texts[2][1])
      assert.equals('GitWordAdd', marks.texts[2][2]) -- Highlight for added

      assert.equals(' more unchanged', marks.texts[3][1])
      assert.is_nil(marks.texts[3][2]) -- No highlight for unchanged
    end)

    it('should calculate correct word diff marks for removed text', function()
      local line_changes = {
        lnum_change = {
          lnum = 3,
          type = 'remove',
          word_diff = {
            { 0, 'unchanged ' },
            { -1, 'removed text' },
            { 0, ' more unchanged' },
          },
        },
      }

      local marks = calculator:calculate_word_diff_marks(line_changes, 3)

      assert.is_not_nil(marks)
      assert.equals(2, marks.row) -- lnum - 1
      assert.equals(0, marks.col)
      assert.equals(3, #marks.texts)

      -- Check text segments
      assert.equals('unchanged ', marks.texts[1][1])
      assert.is_nil(marks.texts[1][2]) -- No highlight for unchanged

      assert.equals('removed text', marks.texts[2][1])
      assert.equals('GitWordDelete', marks.texts[2][2]) -- Highlight for removed

      assert.equals(' more unchanged', marks.texts[3][1])
      assert.is_nil(marks.texts[3][2]) -- No highlight for unchanged
    end)

    it('should return nil for lines without word diff', function()
      local line_changes = {
        lnum_change = {
          lnum = 2,
          type = 'add',
          word_diff = nil,
        },
      }

      local marks = calculator:calculate_word_diff_marks(line_changes, 2)

      assert.is_nil(marks)
    end)

    it('should return nil for lines without lnum_change', function()
      local line_changes = {
        lnum_change = nil,
      }

      local marks = calculator:calculate_word_diff_marks(line_changes, 2)

      assert.is_nil(marks)
    end)
  end)
end)
