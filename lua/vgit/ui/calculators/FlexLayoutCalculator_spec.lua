local FlexLayoutCalculator = require('vgit.ui.calculators.FlexLayoutCalculator')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

local eq = assert.are.same

describe('FlexLayoutCalculator', function()
  local calculator
  local mock_view

  before_each(function()
    calculator = FlexLayoutCalculator()
    mock_view = { mount = function() end }
  end)

  describe('calculate_flex', function()
    it('should distribute space equally for equal flex values', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = calculator:calculate_flex(spec, bounds)

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

      local result = calculator:calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.width)
      eq(200, result.children[2].bounds.width)
    end)

    it('should handle vertical direction', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 300 })
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 2 }),
      })

      local result = calculator:calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.height)
      eq(200, result.children[2].bounds.height)
      -- Both should have full width
      eq(100, result.children[1].bounds.width)
      eq(100, result.children[2].bounds.width)
    end)

    it('should account for gap spacing', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 104, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      }, { gap = 4 })

      local result = calculator:calculate_flex(spec, bounds)

      -- 104 - 4 (gap) = 100, split in half
      eq(50, result.children[1].bounds.width)
      eq(50, result.children[2].bounds.width)
      -- Second child should be offset by width + gap
      eq(54, result.children[2].bounds.col) -- 0 + 50 + 4
    end)

    it('should handle mixed fixed and flex children', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 500, height = 50 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { width = 100 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = calculator:calculate_flex(spec, bounds)

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

      local result = calculator:calculate_flex(spec, bounds)

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

      local result = calculator:calculate_flex(spec, bounds)

      eq(10, result.children[1].bounds.col) -- parent col
      eq(110, result.children[2].bounds.col) -- parent col + 100
      eq(210, result.children[3].bounds.col) -- parent col + 200
      -- All should have same row
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

      local result = calculator:calculate_flex(spec, bounds)

      eq(5, result.children[1].bounds.row) -- parent row
      eq(105, result.children[2].bounds.row) -- parent row + 100
      eq(205, result.children[3].bounds.row) -- parent row + 200
      -- All should have same col
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

      local result = calculator:calculate_flex(spec, bounds)

      -- 101 / 2 = 50.5 -> floor = 50 each, remainder = 1
      -- First flex child gets the remainder
      local total = result.children[1].bounds.width + result.children[2].bounds.width
      eq(101, total)
    end)

    it('should handle gap with vertical direction', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 50, height = 110 })
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      }, { gap = 10 })

      local result = calculator:calculate_flex(spec, bounds)

      -- 110 - 10 (gap) = 100, split in half
      eq(50, result.children[1].bounds.height)
      eq(50, result.children[2].bounds.height)
      -- Second child row should account for gap
      eq(60, result.children[2].bounds.row) -- 0 + 50 + 10
    end)

    it('should handle single child', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = calculator:calculate_flex(spec, bounds)

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

      local result = calculator:calculate_flex(spec, bounds)

      eq(100, result.children[1].bounds.width)
      eq(200, result.children[2].bounds.width)
      eq(300, result.children[3].bounds.width)
    end)
  end)
end)
