local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

local eq = assert.are.same

describe('AbsoluteLayoutCalculator', function()
  local calculator
  local mock_view

  before_each(function()
    calculator = require('vgit.ui.calculators.RootLayoutCalculator')()
    mock_view = { mount = function() end }
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

      local result = calculator:calculate(spec, bounds)

      eq(100, result.bounds.width)
      eq(50, result.bounds.height)
      eq(25, result.bounds.row) -- (100 - 50) / 2
      eq(50, result.bounds.col) -- (200 - 100) / 2
    end)

    it('should position at top-left anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'top-left',
      })

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

      eq(0, result.bounds.row)
      eq(120, result.bounds.col) -- 200 - 80
    end)

    it('should position at bottom-left anchor', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {
        width = 80,
        height = 40,
        anchor = 'bottom-left',
      })

      local result = calculator:calculate(spec, bounds)

      eq(60, result.bounds.row) -- 100 - 40
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

      local result = calculator:calculate(spec, bounds)

      eq(60, result.bounds.row)
      eq(120, result.bounds.col)
    end)

    it('should use parent dimensions when width/height not specified', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.absolute(child_spec, {})

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

      -- center within offset parent
      eq(45, result.bounds.row) -- 20 + (100 - 50) / 2
      eq(80, result.bounds.col) -- 30 + (200 - 100) / 2
    end)
  end)
end)
