local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

local eq = assert.are.same

describe('LayoutBounds:', function()
  describe('convert_dimension', function()
    it('should return nil for nil value', function()
      eq(nil, LayoutBounds.convert_dimension(nil))
    end)

    it('should floor numbers', function()
      eq(42, LayoutBounds.convert_dimension(42))
      eq(10, LayoutBounds.convert_dimension(10.7))
      eq(0, LayoutBounds.convert_dimension(0))
    end)

    it('should convert percentages with parent dimension', function()
      eq(50, LayoutBounds.convert_dimension('50%', 100))
      eq(25, LayoutBounds.convert_dimension('25%', 100))
      eq(150, LayoutBounds.convert_dimension('75%', 200))
    end)

    it('should floor percentage results', function()
      eq(33, LayoutBounds.convert_dimension('33%', 100))
      eq(66, LayoutBounds.convert_dimension('66%', 100))
    end)

    it('should return nil for percentage without parent dimension', function()
      assert.is_nil(LayoutBounds.convert_dimension('50%', nil))
    end)

    it('should convert vh values', function()
      local result = LayoutBounds.convert_dimension('50vh')
      assert.is_number(result)
      assert.is_true(result > 0)
    end)

    it('should convert vw values', function()
      local result = LayoutBounds.convert_dimension('50vw')
      assert.is_number(result)
      assert.is_true(result > 0)
    end)

    it('should handle 100vh', function()
      local result = LayoutBounds.convert_dimension('100vh')
      assert.is_number(result)
      eq(vim.o.lines, result)
    end)

    it('should handle 100vw', function()
      local result = LayoutBounds.convert_dimension('100vw')
      assert.is_number(result)
      eq(vim.o.columns, result)
    end)
  end)

  describe('constructor', function()
    it('should set defaults when no opts given', function()
      local b = LayoutBounds()
      assert.are.equal(0, b.row)
      assert.are.equal(0, b.col)
      assert.are.equal(0, b.width)
      assert.are.equal(0, b.height)
    end)

    it('should set values from opts', function()
      local b = LayoutBounds({ row = 5, col = 10, width = 100, height = 50 })
      assert.are.equal(5, b.row)
      assert.are.equal(10, b.col)
      assert.are.equal(100, b.width)
      assert.are.equal(50, b.height)
    end)
  end)

  describe('apply_constraints', function()
    it('should return nil when value is nil', function()
      assert.is_nil(LayoutBounds.apply_constraints(nil, nil, nil, 200))
    end)

    it('should return value unchanged when no constraints', function()
      assert.are.equal(50, LayoutBounds.apply_constraints(50, nil, nil, 200))
    end)

    it('should clamp to min_value when value is too small', function()
      assert.are.equal(30, LayoutBounds.apply_constraints(10, 30, nil, 200))
    end)

    it('should clamp to max_value when value is too large', function()
      assert.are.equal(80, LayoutBounds.apply_constraints(100, nil, 80, 200))
    end)

    it('should apply both min and max constraints', function()
      assert.are.equal(30, LayoutBounds.apply_constraints(10, 30, 80, 200))
      assert.are.equal(80, LayoutBounds.apply_constraints(100, 30, 80, 200))
      assert.are.equal(50, LayoutBounds.apply_constraints(50, 30, 80, 200))
    end)
  end)

  describe('calculate_anchor_position', function()
    local bounds

    before_each(function()
      bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
    end)

    it('should position top-left', function()
      local row, col = bounds:calculate_anchor_position('top-left', 40, 20)
      assert.are.equal(0, row)
      assert.are.equal(0, col)
    end)

    it('should position top-center', function()
      local row, col = bounds:calculate_anchor_position('top-center', 40, 20)
      assert.are.equal(0, row)
      assert.are.equal(80, col) -- (200 - 40) / 2
    end)

    it('should position top-right', function()
      local row, col = bounds:calculate_anchor_position('top-right', 40, 20)
      assert.are.equal(0, row)
      assert.are.equal(160, col) -- 200 - 40
    end)

    it('should position center-left', function()
      local row, col = bounds:calculate_anchor_position('center-left', 40, 20)
      assert.are.equal(40, row) -- (100 - 20) / 2
      assert.are.equal(0, col)
    end)

    it('should position center', function()
      local row, col = bounds:calculate_anchor_position('center', 40, 20)
      assert.are.equal(40, row) -- (100 - 20) / 2
      assert.are.equal(80, col) -- (200 - 40) / 2
    end)

    it('should position center-right', function()
      local row, col = bounds:calculate_anchor_position('center-right', 40, 20)
      assert.are.equal(40, row)
      assert.are.equal(160, col) -- 200 - 40
    end)

    it('should position bottom-left', function()
      local row, col = bounds:calculate_anchor_position('bottom-left', 40, 20)
      assert.are.equal(80, row) -- 100 - 20
      assert.are.equal(0, col)
    end)

    it('should position bottom-center', function()
      local row, col = bounds:calculate_anchor_position('bottom-center', 40, 20)
      assert.are.equal(80, row) -- 100 - 20
      assert.are.equal(80, col)
    end)

    it('should position bottom-right', function()
      local row, col = bounds:calculate_anchor_position('bottom-right', 40, 20)
      assert.are.equal(80, row) -- 100 - 20
      assert.are.equal(160, col) -- 200 - 40
    end)

    it('should apply row offset for top anchor', function()
      local row, col = bounds:calculate_anchor_position('top-left', 40, 20, { row = 5, col = 0 })
      assert.are.equal(5, row)
      assert.are.equal(0, col)
    end)

    it('should apply col offset for left anchor', function()
      local row, col = bounds:calculate_anchor_position('top-left', 40, 20, { row = 0, col = 10 })
      assert.are.equal(0, row)
      assert.are.equal(10, col)
    end)

    it('should apply offset for center anchor', function()
      local row, col = bounds:calculate_anchor_position('center', 40, 20, { row = 3, col = 7 })
      assert.are.equal(43, row) -- 40 + 3
      assert.are.equal(87, col) -- 80 + 7
    end)

    it('should subtract offset for bottom-right anchor', function()
      local row, col = bounds:calculate_anchor_position('bottom-right', 40, 20, { row = 5, col = 10 })
      assert.are.equal(75, row) -- 100 - 20 - 5
      assert.are.equal(150, col) -- 200 - 40 - 10
    end)

    it('should handle bounds with non-zero origin', function()
      local b = LayoutBounds({ row = 10, col = 20, width = 200, height = 100 })
      local row, col = b:calculate_anchor_position('top-left', 40, 20)
      assert.are.equal(10, row)
      assert.are.equal(20, col)
    end)
  end)

  describe('child_bounds', function()
    local parent

    before_each(function()
      parent = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
    end)

    it('should use allocated dimensions', function()
      local child = parent:child_bounds({}, { width = 50, height = 30, row = 5, col = 10 })
      assert.are.equal(50, child.width)
      assert.are.equal(30, child.height)
      assert.are.equal(5, child.row)
      assert.are.equal(10, child.col)
    end)

    it('should override with spec dimensions', function()
      local child = parent:child_bounds({ width = 80, height = 40 }, { width = 50, height = 30 })
      assert.are.equal(80, child.width)
      assert.are.equal(40, child.height)
    end)

    it('should apply min/max constraints from spec', function()
      local child = parent:child_bounds({ min_width = 60, max_height = 25 }, { width = 50, height = 30 })
      assert.are.equal(60, child.width) -- clamped up from 50
      assert.are.equal(25, child.height) -- clamped down from 30
    end)

    it('should position using anchor from spec', function()
      local child = parent:child_bounds({ anchor = 'center' }, { width = 40, height = 20 })
      assert.are.equal(40, child.row) -- (100 - 20) / 2
      assert.are.equal(80, child.col) -- (200 - 40) / 2
    end)

    it('should default row/col to parent origin when not allocated', function()
      local child = parent:child_bounds({}, { width = 50, height = 30 })
      assert.are.equal(0, child.row)
      assert.are.equal(0, child.col)
    end)
  end)

  describe('to_win_plot', function()
    it('should produce correct window plot', function()
      local b = LayoutBounds({ row = 5, col = 10, width = 80, height = 40 })
      local plot = b:to_win_plot()
      assert.are.equal('editor', plot.relative)
      assert.are.equal(5, plot.row)
      assert.are.equal(10, plot.col)
      assert.are.equal(80, plot.width)
      assert.are.equal(40, plot.height)
      assert.are.equal('minimal', plot.style)
      assert.are.equal(2, plot.zindex)
      assert.is_true(plot.focusable)
    end)

    it('should clamp width and height to minimum of 1', function()
      local b = LayoutBounds({ row = 0, col = 0, width = 0, height = 0 })
      local plot = b:to_win_plot()
      assert.are.equal(1, plot.width)
      assert.are.equal(1, plot.height)
    end)

    it('should accept custom opts', function()
      local b = LayoutBounds({ row = 0, col = 0, width = 50, height = 25 })
      local plot = b:to_win_plot({ relative = 'cursor', zindex = 5, focusable = false })
      assert.are.equal('cursor', plot.relative)
      assert.are.equal(5, plot.zindex)
      assert.is_false(plot.focusable)
    end)
  end)

  describe('clone', function()
    it('should create an independent copy', function()
      local original = LayoutBounds({ row = 5, col = 10, width = 80, height = 40 })
      local copy = original:clone()
      assert.are.equal(5, copy.row)
      assert.are.equal(10, copy.col)
      assert.are.equal(80, copy.width)
      assert.are.equal(40, copy.height)
      -- Clone is a distinct object
      assert.are_not.equal(original, copy)
    end)
  end)

  describe('shrink', function()
    it('should shrink by margin on all sides', function()
      local b = LayoutBounds({ row = 10, col = 20, width = 100, height = 50 })
      local s = b:shrink(5)
      assert.are.equal(15, s.row) -- 10 + 5
      assert.are.equal(25, s.col) -- 20 + 5
      assert.are.equal(90, s.width) -- 100 - 10
      assert.are.equal(40, s.height) -- 50 - 10
    end)

    it('should default margin to 0', function()
      local b = LayoutBounds({ row = 10, col = 20, width = 100, height = 50 })
      local s = b:shrink()
      assert.are.equal(10, s.row)
      assert.are.equal(20, s.col)
      assert.are.equal(100, s.width)
      assert.are.equal(50, s.height)
    end)

    it('should clamp width/height to 0', function()
      local b = LayoutBounds({ row = 0, col = 0, width = 10, height = 10 })
      local s = b:shrink(20)
      assert.are.equal(0, s.width)
      assert.are.equal(0, s.height)
    end)
  end)
end)
