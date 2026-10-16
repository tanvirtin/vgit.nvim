local FoldCalculator = require('vgit.ui.calculators.FoldCalculator')

local eq = assert.are.same

describe('FoldCalculator:', function()
  describe('calculate_folds', function()
    it('should return empty folds when marks is empty', function()
      local folds = FoldCalculator.calculate_folds({}, 200)
      eq({}, folds)
    end)

    it('should return empty folds when line_count is too small', function()
      local folds = FoldCalculator.calculate_folds({ { top = 5, bot = 10 } }, 27)
      eq({}, folds)
    end)

    it('should create fold before first mark when enough space', function()
      local folds = FoldCalculator.calculate_folds({ { top = 50, bot = 60 } }, 200)
      assert.are.equal(2, #folds)
      assert.are.equal(8, folds[1].top)
      assert.are.equal(42, folds[1].bot)
    end)

    it('should create fold after last mark when enough space', function()
      local folds = FoldCalculator.calculate_folds({ { top = 10, bot = 20 } }, 200)
      local after_fold = folds[#folds]
      assert.are.equal(28, after_fold.top)
      assert.are.equal(193, after_fold.bot)
    end)

    it('should create fold between two marks when gap is large enough', function()
      local marks = {
        { top = 10, bot = 20 },
        { top = 80, bot = 90 },
      }
      local folds = FoldCalculator.calculate_folds(marks, 200)
      local found_between = false
      for _, fold in ipairs(folds) do
        if fold.top == 28 and fold.bot == 72 then found_between = true end
      end
      assert.is_true(found_between)
    end)

    it('should not create fold between marks when gap is too small', function()
      local marks = {
        { top = 10, bot = 20 },
        { top = 35, bot = 45 },
      }
      local folds = FoldCalculator.calculate_folds(marks, 200)
      local found_between = false
      for _, fold in ipairs(folds) do
        if fold.top >= 28 and fold.bot <= 27 then found_between = true end
      end
      assert.is_false(found_between)
    end)

    it('should not create fold before first mark when not enough space', function()
      local folds = FoldCalculator.calculate_folds({ { top = 10, bot = 20 } }, 200)
      local found_before = false
      for _, fold in ipairs(folds) do
        if fold.bot < 10 then found_before = true end
      end
      assert.is_false(found_before)
    end)

    it('should respect custom num_focus_lines', function()
      local folds = FoldCalculator.calculate_folds({ { top = 50, bot = 60 } }, 200, 3)
      assert.is_true(#folds >= 1)
      assert.are.equal(4, folds[1].top)
      assert.are.equal(46, folds[1].bot)
    end)

    it('should not create fold that overlaps with a mark', function()
      local marks = {
        { top = 10, bot = 30 },
        { top = 50, bot = 70 },
        { top = 90, bot = 110 },
      }
      local folds = FoldCalculator.calculate_folds(marks, 300)
      for _, fold in ipairs(folds) do
        for _, mark in ipairs(marks) do
          local overlaps = not (fold.bot < mark.top or fold.top > mark.bot)
          assert.is_false(
            overlaps,
            string.format('Fold [%d,%d] overlaps mark [%d,%d]', fold.top, fold.bot, mark.top, mark.bot)
          )
        end
      end
    end)

    it('should handle single mark at line_count boundary', function()
      local folds = FoldCalculator.calculate_folds({ { top = 190, bot = 200 } }, 200)
      assert.is_true(#folds >= 1)
      local after_fold = false
      for _, fold in ipairs(folds) do
        if fold.top > 200 then after_fold = true end
      end
      assert.is_false(after_fold)
    end)

    it('should handle three marks producing folds in all gaps', function()
      local marks = {
        { top = 30, bot = 40 },
        { top = 80, bot = 90 },
        { top = 140, bot = 150 },
      }
      local folds = FoldCalculator.calculate_folds(marks, 300)
      assert.are.equal(4, #folds)
    end)
  end)
end)
