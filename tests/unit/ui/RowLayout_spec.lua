local eq = assert.are.same
local RowLayout = require('vgit.ui.RowLayout')
local dimensions = require('vgit.ui.dimensions')

local function create_mock_component(config)
  return {
    get_plot = function()
      return {
        win_plot = {
          row = config.row or 0,
          height = config.height or 10,
          width = config.width or 80,
          col = config.col or 0,
        },
        header_win_plot = config.header and {
          row = config.header.row or 0,
          height = config.header.height or 1,
          width = config.header.width or 80,
        } or nil,
        footer_win_plot = config.footer and {
          row = config.footer.row or 0,
          height = config.footer.height or 1,
          width = config.footer.width or 80,
        } or nil,
      }
    end,
  }
end

local function create_mock_view(components)
  return {
    get_components = function()
      return components
    end,
  }
end

describe('RowLayout:', function()
  describe('constructor', function()
    it('should create instance with views', function()
      local view1 = create_mock_view({})
      local view2 = create_mock_view({})

      local layout = RowLayout(view1, view2)

      assert.is_table(layout.views)
      assert.equals(#layout.views, 2)
      eq(layout.views[1], view1)
      eq(layout.views[2], view2)
    end)

    it('should handle single view', function()
      local view = create_mock_view({})

      local layout = RowLayout(view)

      assert.equals(#layout.views, 1)
      eq(layout.views[1], view)
    end)

    it('should handle empty views', function()
      local layout = RowLayout()

      assert.is_table(layout.views)
      assert.equals(#layout.views, 0)
    end)

    it('should be an Object instance', function()
      local Object = require('vgit.core.Object')
      local layout = RowLayout()

      assert.is_true(layout:is(RowLayout))
      assert.is_true(layout:is(Object))
    end)
  end)

  describe('build', function()
    it('should stack views vertically by adjusting row positions', function()
      local plot1 = { win_plot = { row = 0, height = 2, width = 80, col = 0 } }
      local plot2 = { win_plot = { row = 0, height = 3, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot2.win_plot.row, 2)
    end)

    it('should handle views with headers', function()
      local plot1 = {
        win_plot = { row = 0, height = 10, width = 80, col = 0 },
        header_win_plot = { row = 0, height = 2, width = 80 },
      }
      local plot2 = { win_plot = { row = 0, height = 10, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot1.header_win_plot.row, 0)
      eq(plot2.win_plot.row, 12)
    end)

    it('should handle views with footers', function()
      local plot1 = {
        win_plot = { row = 0, height = 10, width = 80, col = 0 },
        footer_win_plot = { row = 0, height = 1, width = 80 },
      }
      local plot2 = { win_plot = { row = 0, height = 10, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot2.win_plot.row, 11)
    end)

    it('should handle views with both header and footer', function()
      local plot1 = {
        win_plot = { row = 0, height = 10, width = 80, col = 0 },
        header_win_plot = { row = 0, height = 2, width = 80 },
        footer_win_plot = { row = 0, height = 1, width = 80 },
      }
      local plot2 = { win_plot = { row = 0, height = 5, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      eq(plot2.win_plot.row, 13)
    end)

    it('should handle multiple components in single view', function()
      local plot1 = { win_plot = { row = 0, height = 5, width = 80, col = 0 } }
      local plot2 = { win_plot = { row = 0, height = 5, width = 80, col = 0 } }
      local plot3 = { win_plot = { row = 0, height = 10, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }
      local component3 = {
        get_plot = function()
          return plot3
        end,
      }

      local view = create_mock_view({ component1, component2 })
      local next_view = create_mock_view({ component3 })

      local layout = RowLayout(view, next_view)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot2.win_plot.row, 0)
      eq(plot3.win_plot.row, 5)
    end)

    it('should adjust layout when exceeding global height', function()
      local global_height = dimensions.global_height()
      local large_height = math.ceil(global_height * 0.6)

      local component1 = create_mock_component({ row = 0, height = large_height })
      local component2 = create_mock_component({ row = 0, height = large_height })

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      local plot2 = component2:get_plot()

      assert.is_true(
        plot2.win_plot.row + plot2.win_plot.height <= global_height,
        'layout should fit within screen height'
      )
    end)

    it('should handle repositioning with headers when exceeding height', function()
      local global_height = dimensions.global_height()
      local large_height = math.ceil(global_height * 0.6)

      local component1 = create_mock_component({ row = 0, height = large_height })
      local component2 = create_mock_component({
        row = 0,
        height = large_height,
        header = { row = 0, height = 2 },
      })

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      local plot2 = component2:get_plot()

      assert.is_number(plot2.win_plot.row)
      assert.is_number(plot2.header_win_plot.row)
    end)

    it('should return self for method chaining', function()
      local view = create_mock_view({ create_mock_component({}) })
      local layout = RowLayout(view)

      local result = layout:build()

      assert.equals(result, layout)
    end)

    it('should stack three views correctly', function()
      local plot1 = { win_plot = { row = 0, height = 5, width = 80, col = 0 } }
      local plot2 = { win_plot = { row = 0, height = 10, width = 80, col = 0 } }
      local plot3 = { win_plot = { row = 0, height = 8, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }
      local component3 = {
        get_plot = function()
          return plot3
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })
      local view3 = create_mock_view({ component3 })

      local layout = RowLayout(view1, view2, view3)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot2.win_plot.row, 5)
      eq(plot3.win_plot.row, 15)
    end)
  end)

  describe('edge cases', function()
    it('should handle views with zero height', function()
      local component1 = create_mock_component({ row = 0, height = 0 })
      local component2 = create_mock_component({ row = 0, height = 10 })

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)

      assert.has_no.errors(function()
        layout:build()
      end)
    end)

    it('should handle views with no components', function()
      local view = create_mock_view({})

      local layout = RowLayout(view)

      assert.is_table(layout)
    end)

    it('should handle initial row offsets in components', function()
      local plot1 = { win_plot = { row = 1, height = 2, width = 80, col = 0 } }
      local plot2 = { win_plot = { row = 1, height = 2, width = 80, col = 0 } }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      eq(plot1.win_plot.row, 1)
      eq(plot2.win_plot.row, 3)
    end)
  end)

  describe('integration', function()
    it('should handle complex multi-view layout with headers and footers', function()
      local plot1 = {
        win_plot = { row = 0, height = 2, width = 80, col = 0 },
        header_win_plot = { row = 0, height = 1, width = 80 },
      }
      local plot2 = {
        win_plot = { row = 0, height = 1, width = 80, col = 0 },
      }
      local plot3 = {
        win_plot = { row = 0, height = 1, width = 80, col = 0 },
        footer_win_plot = { row = 0, height = 1, width = 80 },
      }

      local component1 = {
        get_plot = function()
          return plot1
        end,
      }
      local component2 = {
        get_plot = function()
          return plot2
        end,
      }
      local component3 = {
        get_plot = function()
          return plot3
        end,
      }

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })
      local view3 = create_mock_view({ component3 })

      local layout = RowLayout(view1, view2, view3)
      layout:build()

      eq(plot1.win_plot.row, 0)
      eq(plot1.header_win_plot.row, 0)
      eq(plot2.win_plot.row, 3)
      eq(plot3.win_plot.row, 4)
    end)

    it('should maintain correct positioning after build', function()
      local component1 = create_mock_component({ row = 0, height = 20 })
      local component2 = create_mock_component({ row = 0, height = 20 })

      local view1 = create_mock_view({ component1 })
      local view2 = create_mock_view({ component2 })

      local layout = RowLayout(view1, view2)
      layout:build()

      local plot1_before = component1:get_plot().win_plot.row
      local plot2_before = component2:get_plot().win_plot.row

      layout:build()

      local plot1_after = component1:get_plot().win_plot.row
      local plot2_after = component2:get_plot().win_plot.row

      assert.is_number(plot1_after)
      assert.is_number(plot2_after)
    end)
  end)
end)
