local FoldCalculator = require('vgit.ui.calculators.FoldCalculator')

describe('FoldCalculator', function()
  local calculator

  before_each(function()
    calculator = FoldCalculator()
  end)

  describe('calculate_folds', function()
    it('should calculate folds for large files with marks', function()
      local marks = {
        { top = 1, bot = 10 },
        { top = 20, bot = 30 },
        { top = 40, bot = 50 },
      }
      local line_count = 100

      local folds = calculator:calculate_folds(marks, line_count)

      assert.is_not_nil(folds)
      assert.is_true(#folds >= 0)
    end)

    it('should return empty folds for small files', function()
      local marks = {
        { top = 1, bot = 5 },
      }
      local line_count = 20

      local folds = calculator:calculate_folds(marks, line_count)

      assert.equals(0, #folds)
    end)

    it('should return empty folds for no marks', function()
      local marks = {}
      local line_count = 100

      local folds = calculator:calculate_folds(marks, line_count)

      assert.equals(0, #folds)
    end)

    it('should return empty folds for insufficient line count', function()
      local marks = {
        { top = 1, bot = 5 },
      }
      local line_count = 10

      local folds = calculator:calculate_folds(marks, line_count)

      assert.equals(0, #folds)
    end)

    it('should create fold before first mark when sufficient space', function()
      local marks = {
        { top = 50, bot = 60 },
      }
      local line_count = 200

      local folds = calculator:calculate_folds(marks, line_count)

      assert.is_true(#folds > 0)
      local first_fold = folds[1]
      assert.equals(8, first_fold.top)
      assert.is_true(first_fold.bot < 50)
    end)

    it('should create fold after last mark when sufficient space', function()
      local marks = {
        { top = 10, bot = 20 },
      }
      local line_count = 200

      local folds = calculator:calculate_folds(marks, line_count)

      assert.is_true(#folds > 0)
      local last_fold = folds[#folds]
      assert.is_true(last_fold.top > 20)
      assert.is_true(last_fold.bot <= 200)
    end)

    it('should create folds between consecutive marks', function()
      local marks = {
        { top = 10, bot = 15 },
        { top = 50, bot = 55 },
      }
      local line_count = 200

      local folds = calculator:calculate_folds(marks, line_count)

      local has_middle_fold = false
      for _, fold in ipairs(folds) do
        if fold.top > 15 and fold.bot < 50 then
          has_middle_fold = true
          break
        end
      end
      assert.is_true(has_middle_fold)
    end)

    it('should only create folds with minimum 10 lines', function()
      local marks = {
        { top = 10, bot = 15 },
        { top = 30, bot = 35 },
      }
      local line_count = 100

      local folds = calculator:calculate_folds(marks, line_count)

      for _, fold in ipairs(folds) do
        local fold_size = fold.bot - fold.top + 1
        assert.is_true(fold_size >= 10)
      end
    end)

    it('should not create overlapping folds with marks', function()
      local marks = {
        { top = 20, bot = 30 },
        { top = 60, bot = 70 },
      }
      local line_count = 200

      local folds = calculator:calculate_folds(marks, line_count)

      for _, fold in ipairs(folds) do
        for _, mark in ipairs(marks) do
          local overlaps = not (fold.bot < mark.top or fold.top > mark.bot)
          assert.is_false(overlaps)
        end
      end
    end)
  end)

  describe('apply_folds', function()
    it('should apply folds to element', function()
      local original_vim_cmd = vim.cmd
      local cmd_calls = {}
      vim.cmd = function(cmd)
        table.insert(cmd_calls, cmd)
      end

      local element = {
        call = function(self, callback)
          callback()
        end,
      }

      local folds = {
        { top = 10, bot = 20 },
        { top = 30, bot = 40 },
      }

      assert.has_no.errors(function()
        calculator:apply_folds(element, folds)
      end)

      assert.equals(2, #cmd_calls)
      assert.equals('10,20fold', cmd_calls[1])
      assert.equals('30,40fold', cmd_calls[2])

      vim.cmd = original_vim_cmd
    end)

    it('should handle empty folds', function()
      local element = {
        call = function(self, callback)
          callback()
        end,
      }

      local folds = {}

      assert.has_no.errors(function()
        calculator:apply_folds(element, folds)
      end)
    end)
  end)

  describe('clear_folds', function()
    it('should clear folds from element', function()
      local original_nvim_command = vim.api.nvim_command
      local command_called = false
      vim.api.nvim_command = function(cmd)
        command_called = true
        assert.equals('normal! zR', cmd)
      end

      local element = {
        call = function(self, callback)
          callback()
        end,
      }

      assert.has_no.errors(function()
        calculator:clear_folds(element)
      end)

      assert.is_true(command_called)

      -- Restore vim.api.nvim_command
      vim.api.nvim_command = original_nvim_command
    end)
  end)
end)
