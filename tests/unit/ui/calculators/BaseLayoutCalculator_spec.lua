local BaseLayoutCalculator = require('vgit.ui.calculators.BaseLayoutCalculator')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

local eq = assert.are.same

describe('BaseLayoutCalculator', function()
  local calculator
  local mock_view

  before_each(function()
    -- Use a full RootLayoutCalculator since BaseLayoutCalculator alone
    -- doesn't implement calculate_flex or calculate_absolute
    calculator = require('vgit.ui.calculators.RootLayoutCalculator')()
    mock_view = { mount = function() end }
  end)

  describe('calculate', function()
    it('should dispatch to calculate_view for view specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = LayoutSpec.view(mock_view, { flex = 1 })

      local result = calculator:calculate(spec, bounds)

      assert.is_not_nil(result)
      assert.is_not_nil(result.bounds)
      eq(0, #result.children)
    end)

    it('should dispatch to calculate_container for container specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.container(child_spec)

      local result = calculator:calculate(spec, bounds)

      assert.is_not_nil(result)
      eq(1, #result.children)
    end)

    it('should dispatch to calculate_flex for flex specs', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(mock_view, { flex = 1 }),
        LayoutSpec.view(mock_view, { flex = 1 }),
      })

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

      assert.is_not_nil(result)
      eq(1, #result.children)
    end)

    it('should error on unknown spec type', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = 50 })
      local spec = { type = 'unknown_type' }

      assert.has_error(function()
        calculator:calculate(spec, bounds)
      end)
    end)

    it('should error when spec is nil', function()
      assert.has_error(function()
        calculator:calculate(nil)
      end)
    end)
  end)

  describe('calculate_container', function()
    it('should pass through to child calculation', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 200, height = 100 })
      local child_spec = LayoutSpec.view(mock_view, { flex = 1 })
      local spec = LayoutSpec.container(child_spec)

      local result = calculator:calculate(spec, bounds)

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

      local result = calculator:calculate(spec, bounds)

      eq(200, result.bounds.width)
      eq(100, result.bounds.height)
      eq(5, result.bounds.row)
      eq(10, result.bounds.col)
      eq(0, #result.children)
    end)
  end)
end)
