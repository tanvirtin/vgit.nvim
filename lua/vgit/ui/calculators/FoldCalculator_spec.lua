local FoldCalculator = require('vgit.ui.calculators.FoldCalculator')

describe('FoldCalculator', function()
  local calc

  before_each(function()
    calc = FoldCalculator()
  end)

  describe('calculate_folds', function()
    it('should return empty folds when marks is empty', function()
      local folds = calc:calculate_folds({}, 200)
      assert.are.same({}, folds)
    end)

    it('should return empty folds when line_count is too small', function()
      -- Default num_focus_lines=7, threshold is 7*4=28
      local folds = calc:calculate_folds({ { top = 5, bot = 10 } }, 27)
      assert.are.same({}, folds)
    end)

    it('should create fold before first mark when enough space', function()
      -- num_focus_lines=7, mark at top=50, bot=60, line_count=200
      -- Before first mark: top=8, bot=50-7-1=42 -> range [8,42] = 35 lines >= 10
      -- After last mark: top=68, bot=193 -> also creates fold
      local folds = calc:calculate_folds({ { top = 50, bot = 60 } }, 200)
      assert.are.equal(2, #folds)
      -- First fold is before the mark
      assert.are.equal(8, folds[1].top)
      assert.are.equal(42, folds[1].bot)
    end)

    it('should create fold after last mark when enough space', function()
      -- Mark at top=10, bot=20, line_count=200
      -- After last mark: top=20+7+1=28, bot=200-7=193 -> range [28,193] = 166 lines >= 10
      local folds = calc:calculate_folds({ { top = 10, bot = 20 } }, 200)
      -- Should have fold before and fold after
      local after_fold = folds[#folds]
      assert.are.equal(28, after_fold.top) -- 20+7+1
      assert.are.equal(193, after_fold.bot) -- 200-7
    end)

    it('should create fold between two marks when gap is large enough', function()
      -- Two marks far apart
      local marks = {
        { top = 10, bot = 20 },
        { top = 80, bot = 90 },
      }
      local folds = calc:calculate_folds(marks, 200)
      -- Between marks: top=20+7+1=28, bot=80-7-1=72 -> range [28,72] = 45 lines >= 10
      local found_between = false
      for _, fold in ipairs(folds) do
        if fold.top == 28 and fold.bot == 72 then
          found_between = true
        end
      end
      assert.is_true(found_between)
    end)

    it('should not create fold between marks when gap is too small', function()
      -- Two marks close together
      local marks = {
        { top = 10, bot = 20 },
        { top = 35, bot = 45 },
      }
      -- Between: top=20+7+1=28, bot=35-7-1=27 -> 28 > 27, skip
      local folds = calc:calculate_folds(marks, 200)
      local found_between = false
      for _, fold in ipairs(folds) do
        if fold.top >= 28 and fold.bot <= 27 then
          found_between = true
        end
      end
      assert.is_false(found_between)
    end)

    it('should not create fold before first mark when not enough space', function()
      -- Mark starts at top=10, num_focus_lines=7
      -- Before: top=8, bot=10-7-1=2 -> 8 > 2, skip
      local folds = calc:calculate_folds({ { top = 10, bot = 20 } }, 200)
      local found_before = false
      for _, fold in ipairs(folds) do
        if fold.bot < 10 then found_before = true end
      end
      assert.is_false(found_before)
    end)

    it('should respect custom num_focus_lines', function()
      -- With num_focus_lines=3, threshold=3*4=12
      -- Mark at top=50, bot=60, line_count=200
      -- Before: top=4, bot=50-3-1=46, range [4,46]=43 >= 10
      local folds = calc:calculate_folds({ { top = 50, bot = 60 } }, 200, 3)
      assert.is_true(#folds >= 1)
      assert.are.equal(4, folds[1].top)
      assert.are.equal(46, folds[1].bot)
    end)

    it('should not create fold that overlaps with a mark', function()
      -- The is_safe_fold check ensures no fold overlaps any mark
      local marks = {
        { top = 10, bot = 30 },
        { top = 50, bot = 70 },
        { top = 90, bot = 110 },
      }
      local folds = calc:calculate_folds(marks, 300)
      for _, fold in ipairs(folds) do
        for _, mark in ipairs(marks) do
          -- Fold should not overlap any mark
          local overlaps = not (fold.bot < mark.top or fold.top > mark.bot)
          assert.is_false(overlaps, string.format(
            'Fold [%d,%d] overlaps mark [%d,%d]', fold.top, fold.bot, mark.top, mark.bot
          ))
        end
      end
    end)

    it('should handle single mark at line_count boundary', function()
      -- Mark at the very end
      local folds = calc:calculate_folds({ { top = 190, bot = 200 } }, 200)
      -- Before: top=8, bot=190-7-1=182, range [8,182]=175 >= 10 -> fold
      -- After: top=200+7+1=208, bot=200-7=193 -> 208 > 193, skip
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
      local folds = calc:calculate_folds(marks, 300)
      -- Should produce: before first, between 1&2, between 2&3, after last
      assert.are.equal(4, #folds)
    end)
  end)
end)
