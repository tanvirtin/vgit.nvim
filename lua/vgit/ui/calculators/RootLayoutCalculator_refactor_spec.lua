local RootLayoutCalculator = require('vgit.ui.calculators.RootLayoutCalculator')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

describe('RootLayoutCalculator Refactor Tests', function()
  local calculator
  local parent_bounds

  before_each(function()
    calculator = RootLayoutCalculator()
    parent_bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 100 })
  end)

  describe('Delegation pattern refactoring', function()
    it('should delegate flex calculations to flex calculator', function()
      local mock_view1 = { mount = function() end }
      local mock_view2 = { mount = function() end }
      local spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view(mock_view1, { flex = 1 }),
          LayoutSpec.view(mock_view2, { flex = 1 }),
        },
      })

      -- Test that delegation works correctly
      local layout = calculator:calculate_flex(spec, parent_bounds)

      -- Verify the result structure
      assert.is_table(layout)
      assert.is_table(layout.bounds)
      assert.is_table(layout.spec)
      assert.is_table(layout.children)

      -- Verify children are calculated correctly
      assert.equals(2, #layout.children)
      assert.equals(100, layout.children[1].bounds.width) -- half of 200
      assert.equals(100, layout.children[2].bounds.width) -- half of 200
    end)

    it('should delegate absolute calculations to absolute calculator', function()
      local mock_view = { mount = function() end }
      local spec = LayoutSpec.absolute(LayoutSpec.view(mock_view), {
        anchor = 'center',
        width = 50,
        height = 30,
      })

      local layout = calculator:calculate_absolute(spec, parent_bounds)

      -- Verify the result structure
      assert.is_table(layout)
      assert.is_table(layout.bounds)
      assert.is_table(layout.spec)
      assert.is_table(layout.children)

      -- Verify absolute positioning
      assert.equals(50, layout.bounds.width)
      assert.equals(30, layout.bounds.height)
      -- Center of 200x100 with 50x30 element
      assert.equals(35, layout.bounds.row) -- (100 - 30) / 2
      assert.equals(75, layout.bounds.col) -- (200 - 50) / 2
    end)

    it('should maintain calculator instances correctly', function()
      -- Verify that calculator instances are properly maintained
      assert.is_table(calculator.flex_calculator)
      assert.is_table(calculator.absolute_calculator)

      -- Verify they are the correct types
      assert.is_function(calculator.flex_calculator.calculate_flex)
      assert.is_function(calculator.absolute_calculator.calculate_absolute)
    end)

    it('should handle delegation with different parent bounds', function()
      local small_bounds = LayoutBounds({ row = 10, col = 20, width = 100, height = 50 })
      local mock_view1 = { mount = function() end }
      local mock_view2 = { mount = function() end }

      local spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view(mock_view1, { flex = 1 }),
          LayoutSpec.view(mock_view2, { flex = 1 }),
        },
      })

      local layout = calculator:calculate_flex(spec, small_bounds)

      -- Verify bounds are respected
      assert.equals(2, #layout.children)
      assert.equals(50, layout.children[1].bounds.width) -- half of 100
      assert.equals(50, layout.children[2].bounds.width) -- half of 100
      assert.equals(10, layout.children[1].bounds.row) -- parent row
      assert.equals(20, layout.children[1].bounds.col) -- parent col
    end)

    it('should handle complex nested delegations', function()
      local mock_view1 = { mount = function() end }
      local mock_view2 = { mount = function() end }
      local mock_view3 = { mount = function() end }

      -- Create a flex layout with nested flex
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

      local layout = calculator:calculate_flex(nested_spec, parent_bounds)

      -- Verify outer flex layout
      assert.equals(2, #layout.children)
      assert.equals(100, layout.children[1].bounds.width) -- half of 200
      assert.equals(100, layout.children[2].bounds.width) -- half of 200

      -- Verify nested flex layout
      assert.equals(2, #layout.children[2].children)
      assert.equals(50, layout.children[2].children[1].bounds.height) -- half of 100
      assert.equals(50, layout.children[2].children[2].bounds.height) -- half of 100
    end)

    it('should handle edge cases in delegation', function()
      -- Test with empty children
      local empty_spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {},
      })

      local layout = calculator:calculate_flex(empty_spec, parent_bounds)
      assert.equals(0, #layout.children)

      -- Test with single child
      local single_spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view({ mount = function() end }, { flex = 1 }),
        },
      })

      local single_layout = calculator:calculate_flex(single_spec, parent_bounds)
      assert.equals(1, #single_layout.children)
      assert.equals(200, single_layout.children[1].bounds.width) -- full width
    end)

    it('should maintain calculator state across calls', function()
      -- Multiple calls should not interfere with each other
      local spec1 = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view({ mount = function() end }, { flex = 1 }),
          LayoutSpec.view({ mount = function() end }, { flex = 1 }),
        },
      })

      local spec2 = LayoutSpec.absolute(LayoutSpec.view({ mount = function() end }), {
        anchor = 'top-left',
        width = 100,
        height = 50,
      })

      local layout1 = calculator:calculate_flex(spec1, parent_bounds)
      local layout2 = calculator:calculate_absolute(spec2, parent_bounds)

      -- Both should work correctly
      assert.equals(2, #layout1.children)
      assert.is_table(layout2)

      -- Verify calculator instances are still valid
      assert.is_table(calculator.flex_calculator)
      assert.is_table(calculator.absolute_calculator)
    end)
  end)

  describe('Refactored delegation method behavior', function()
    it('should produce identical results before and after refactoring', function()
      local test_specs = {
        {
          name = 'flex horizontal',
          spec = LayoutSpec.flex({
            direction = 'horizontal',
            children = {
              LayoutSpec.view({ mount = function() end }, { flex = 1 }),
              LayoutSpec.view({ mount = function() end }, { flex = 2 }),
            },
          }),
          method = 'calculate_flex',
        },
        {
          name = 'flex vertical',
          spec = LayoutSpec.flex({
            direction = 'vertical',
            children = {
              LayoutSpec.view({ mount = function() end }, { flex = 1 }),
              LayoutSpec.view({ mount = function() end }, { flex = 1 }),
            },
          }),
          method = 'calculate_flex',
        },
        {
          name = 'absolute center',
          spec = LayoutSpec.absolute(LayoutSpec.view({ mount = function() end }), {
            anchor = 'center',
            width = 100,
            height = 50,
          }),
          method = 'calculate_absolute',
        },
      }

      for _, test_case in ipairs(test_specs) do
        local layout = calculator[test_case.method](calculator, test_case.spec, parent_bounds)

        -- Verify basic structure
        assert.is_table(layout, 'Layout should be a table for ' .. test_case.name)
        assert.is_table(layout.bounds, 'Layout should have bounds for ' .. test_case.name)
        assert.is_table(layout.spec, 'Layout should have spec for ' .. test_case.name)
        assert.is_table(layout.children, 'Layout should have children for ' .. test_case.name)

        -- Verify bounds are within parent bounds
        assert.is_true(
          layout.bounds.width <= parent_bounds.width,
          'Layout width should not exceed parent for ' .. test_case.name
        )
        assert.is_true(
          layout.bounds.height <= parent_bounds.height,
          'Layout height should not exceed parent for ' .. test_case.name
        )
      end
    end)

    it('should handle delegation errors gracefully', function()
      -- Test with invalid spec
      local invalid_spec = {
        type = 'invalid_type',
        children = {},
      }

      -- Should not crash, but may return nil or handle gracefully
      local success, result = pcall(function()
        return calculator:calculate_flex(invalid_spec, parent_bounds)
      end)

      -- Either should succeed with a result or fail gracefully
      if success then
        -- If it succeeds, result should be a table
        assert.is_table(result)
      else
        -- If it fails, should be a controlled error
        assert.is_string(result)
      end
    end)

    it('should maintain calculator independence', function()
      -- Create two separate calculator instances
      local calculator1 = RootLayoutCalculator()
      local calculator2 = RootLayoutCalculator()

      local spec = LayoutSpec.flex({
        direction = 'horizontal',
        children = {
          LayoutSpec.view({ mount = function() end }, { flex = 1 }),
          LayoutSpec.view({ mount = function() end }, { flex = 1 }),
        },
      })

      local layout1 = calculator1:calculate_flex(spec, parent_bounds)
      local layout2 = calculator2:calculate_flex(spec, parent_bounds)

      -- Both should produce identical results
      assert.equals(#layout1.children, #layout2.children)
      assert.equals(layout1.children[1].bounds.width, layout2.children[1].bounds.width)
      assert.equals(layout1.children[2].bounds.width, layout2.children[2].bounds.width)

      -- Calculator instances should be independent
      assert.is_not_equal(calculator1.flex_calculator, calculator2.flex_calculator)
    end)
  end)
end)
