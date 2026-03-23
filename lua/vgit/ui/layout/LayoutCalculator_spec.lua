local LayoutCalculator = require('vgit.ui.layout.LayoutCalculator')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

local eq = assert.are.same

describe('LayoutCalculator:', function()
  local mock_view

  before_each(function()
    mock_view = { mount = function() end }
  end)

  describe('calculate', function()
    it('should dispatch to calculate_view for view specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = LayoutSpec.view(mock_view, { flex = 1 })

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_not_nil(result)
      assert.is_not_nil(result.bounds)
      eq(0, #result.children)
    end)

    it('should dispatch to calculate_container for container specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.container(child_spec)

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_not_nil(result)
      eq(1, #result.children)
    end)

    it('should dispatch to calculate_flex for flex specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_not_nil(result)
      eq(2, #result.children)
    end)

    it('should dispatch to calculate_absolute for absolute specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 100,
        height = 50,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_not_nil(result)
      eq(1, #result.children)
    end)

    it('should error on unknown spec type', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = { type = 'unknown_type' }

      assert.has_error(function()
        LayoutCalculator.calculate(spec, bounds)
      end)
    end)

    it('should error when spec is nil', function()
      assert.has_error(function()
        LayoutCalculator.calculate(nil)
      end)
    end)
  end)

  describe('calculate_container', function()
    it('should pass through to child calculation', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.container(child_spec)

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(bounds, result.bounds)
      eq(1, #result.children)
      eq(5, result.children[1].bounds.row)
      eq(10, result.children[1].bounds.col)
    end)
  end)

  describe('calculate_view', function()
    it('should use parent bounds', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 200, height = 100 })
      local spec = LayoutSpec.view(mock_view, { flex = 1 })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(200, result.bounds.width)
      eq(100, result.bounds.height)
      eq(5, result.bounds.row)
      eq(10, result.bounds.col)
      eq(0, #result.children)
    end)
  end)

  describe('calculate_flex', function()
    it('should distribute space equally for equal flex values', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(2, #result.children)
      eq(50, result.children[1].bounds.width)
      eq(50, result.children[2].bounds.width)
    end)

    it('should distribute space proportionally for unequal flex', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 300, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 2 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.width)
      eq(200, result.children[2].bounds.width)
    end)

    it('should handle vertical direction', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 300 })
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 2 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.height)
      eq(200, result.children[2].bounds.height)
      eq(100, result.children[1].bounds.width)
      eq(100, result.children[2].bounds.width)
    end)

    it('should account for gap spacing', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 104, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      }, { gap = 4 })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(50, result.children[1].bounds.width)
      eq(50, result.children[2].bounds.width)
      eq(54, result.children[2].bounds.col)
    end)

    it('should handle mixed fixed and flex children', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 500, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { width = 100 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.width)
      eq(200, result.children[2].bounds.width)
      eq(200, result.children[3].bounds.width)
    end)

    it('should handle empty children', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = {
        type = 'flex',
        direction = 'horizontal',
        children = {},
      }

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(0, #result.children)
      eq(bounds, result.bounds)
    end)

    it('should position children correctly in horizontal direction', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 300, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(10, result.children[1].bounds.col)
      eq(110, result.children[2].bounds.col)
      eq(210, result.children[3].bounds.col)
      eq(5, result.children[1].bounds.row)
      eq(5, result.children[2].bounds.row)
      eq(5, result.children[3].bounds.row)
    end)

    it('should position children correctly in vertical direction', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 100, height = 300 })
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(5, result.children[1].bounds.row)
      eq(105, result.children[2].bounds.row)
      eq(205, result.children[3].bounds.row)
      eq(10, result.children[1].bounds.col)
      eq(10, result.children[2].bounds.col)
      eq(10, result.children[3].bounds.col)
    end)

    it('should distribute remainder pixels to flex children', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 101, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      local total = result.children[1].bounds.width + result.children[2].bounds.width
      eq(101, total)
    end)

    it('should handle gap with vertical direction', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 50, height = 110 })
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      }, { gap = 10 })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(50, result.children[1].bounds.height)
      eq(50, result.children[2].bounds.height)
      eq(60, result.children[2].bounds.row)
    end)

    it('should handle single child', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(1, #result.children)
      eq(200, result.children[1].bounds.width)
      eq(100, result.children[1].bounds.height)
    end)

    it('should handle 3-way split with 1:2:3 ratio', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 600, height = 100 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 2 }),
        LayoutSpec.view(mock_view, { flex = 3 }),
      })

      local result = LayoutCalculator.calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.width)
      eq(200, result.children[2].bounds.width)
      eq(300, result.children[3].bounds.width)
    end)

    it('should handle nested flex layouts', function()
      local mock_view1 = { mount = function() end }
      local mock_view2 = { mount = function() end }
      local mock_view3 = { mount = function() end }

      local nested_spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view(mock_view1, { flex = 1 }),
          LayoutSpec.flex({
            direction = 'vertical',
            flex = 1,
            children = {
              LayoutSpec.view(mock_view2, { flex = 1 }),
              LayoutSpec.view(mock_view3, { flex = 1 }),
            },
          }),
        },
      })

      local parent_bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local layout = LayoutCalculator.calculate_flex(nested_spec, parent_bounds)

      eq(2, #layout.children)
      eq(100, layout.children[1].bounds.width)
      eq(100, layout.children[2].bounds.width)

      eq(2, #layout.children[2].children)
      eq(50, layout.children[2].children[1].bounds.height)
      eq(50, layout.children[2].children[2].bounds.height)
    end)
  end)

  describe('calculate_absolute', function()
    it('should center a child in parent bounds', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 100,
        height = 50,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(100, result.bounds.width)
      eq(50, result.bounds.height)
      eq(25, result.bounds.row)
      eq(50, result.bounds.col)
    end)

    it('should position at top-left anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'top-left',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(0, result.bounds.row)
      eq(0, result.bounds.col)
      eq(80, result.bounds.width)
      eq(40, result.bounds.height)
    end)

    it('should position at top-right anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'top-right',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(0, result.bounds.row)
      eq(120, result.bounds.col)
    end)

    it('should position at bottom-left anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'bottom-left',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(60, result.bounds.row)
      eq(0, result.bounds.col)
    end)

    it('should position at bottom-right anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'bottom-right',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(60, result.bounds.row)
      eq(120, result.bounds.col)
    end)

    it('should use parent dimensions when width/height not specified', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {})

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(200, result.bounds.width)
      eq(100, result.bounds.height)
    end)

    it('should handle offset with anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 100,
        height = 50,
        anchor = 'top-left',
        offset = { row = 5, col = 10 },
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(5, result.bounds.row)
      eq(10, result.bounds.col)
    end)

    it('should position without anchor using row/col', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = {
        type = 'absolute',
        child = child_spec,
        width = 80,
        height = 40,
        row = 10,
        col = 20,
      }

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(10, result.bounds.row)
      eq(20, result.bounds.col)
      eq(80, result.bounds.width)
      eq(40, result.bounds.height)
    end)

    it('should handle absolute with no child', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local spec = LayoutSpec.absolute(nil, {
        width = 100,
        height = 50,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(0, #result.children)
    end)

    it('should apply min/max constraints', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 300,
        height = 150,
        max_width = 180,
        max_height = 80,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_true(result.bounds.width <= 180)
      assert.is_true(result.bounds.height <= 80)
    end)

    it('should apply min constraints', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 10,
        height = 5,
        min_width = 50,
        min_height = 30,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      assert.is_true(result.bounds.width >= 50)
      assert.is_true(result.bounds.height >= 30)
    end)

    it('should handle parent with non-zero origin', function()
      local bounds = LayoutBounds({ row = 20, col = 30, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 100,
        height = 50,
        anchor = 'center',
      })

      local result = LayoutCalculator.calculate(spec, bounds)

      eq(45, result.bounds.row)
      eq(80, result.bounds.col)
    end)
  end)
end)
