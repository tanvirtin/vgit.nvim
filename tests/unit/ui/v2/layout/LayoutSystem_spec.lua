local LayoutCalculator = require('vgit.ui.layout.LayoutCalculator')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')

describe('Layout System', function()
  local calculator

  before_each(function()
    calculator = LayoutCalculator()
  end)

  -- ============================================================================
  -- FLEX RATIOS & SPACE DISTRIBUTION
  -- ============================================================================
  describe('Flex Ratio Calculations', function()
    it('should handle 1:1, 1:2, and 1:2:3 ratios', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 600, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      -- 1:1 ratio (300 each)
      local spec_1_1 = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1 }),
        LayoutSpec.view(v2, { flex = 1 }),
      })
      local layout = calculator:calculate(spec_1_1, viewport)
      assert.are.equal(300, layout.children[1].bounds.width)
      assert.are.equal(300, layout.children[2].bounds.width)

      -- 1:2 ratio (200, 400)
      local spec_1_2 = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1 }),
        LayoutSpec.view(v2, { flex = 2 }),
      })
      layout = calculator:calculate(spec_1_2, viewport)
      assert.are.equal(200, layout.children[1].bounds.width)
      assert.are.equal(400, layout.children[2].bounds.width)

      -- 1:2:3 ratio (100, 200, 300)
      local spec_1_2_3 = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1 }),
        LayoutSpec.view(v2, { flex = 2 }),
        LayoutSpec.view(v3, { flex = 3 }),
      })
      layout = calculator:calculate(spec_1_2_3, viewport)
      assert.are.equal(100, layout.children[1].bounds.width)
      assert.are.equal(200, layout.children[2].bounds.width)
      assert.are.equal(300, layout.children[3].bounds.width)
    end)

    it('should handle fractional flex values', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 0.5 }),
        LayoutSpec.view(v2, { flex = 1.5 }),
        LayoutSpec.view(v3, { flex = 3 }),
      })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(100, layout.children[1].bounds.width)
      assert.are.equal(300, layout.children[2].bounds.width)
      assert.are.equal(600, layout.children[3].bounds.width)
    end)

    it('should mix fixed sizes with flex', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { width = 200 }),
        LayoutSpec.view(v2, { flex = 1 }),
        LayoutSpec.view(v3, { flex = 3 }),
      })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(200, layout.children[1].bounds.width)
      assert.are.equal(200, layout.children[2].bounds.width) -- 1/4 of remaining 800
      assert.are.equal(600, layout.children[3].bounds.width) -- 3/4 of remaining 800
    end)

    it('should distribute remainder to last flex child', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1 }),
        LayoutSpec.view(v2, { flex = 1 }),
        LayoutSpec.view(v3, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, viewport)

      -- 100/3 = 33.33... → 33, 33, 34
      assert.are.equal(33, layout.children[1].bounds.width)
      assert.are.equal(33, layout.children[2].bounds.width)
      assert.are.equal(34, layout.children[3].bounds.width)

      -- Verify no pixels lost
      local total = layout.children[1].bounds.width + layout.children[2].bounds.width + layout.children[3].bounds.width
      assert.are.equal(100, total)
    end)
  end)

  -- ============================================================================
  -- GAPS & SPACING
  -- ============================================================================
  describe('Gap Calculations', function()
    it('should handle gaps with 2 and 5 children', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2, v3, v4, v5 =
        { mount = function() end },
        { mount = function() end },
        { mount = function() end },
        { mount = function() end },
        { mount = function() end }

      -- 2 children with 10px gap
      local spec_2 = LayoutSpec.flex({
        direction = 'horizontal',
        gap = 10,
        children = {
          LayoutSpec.view(v1, { flex = 1 }),
          LayoutSpec.view(v2, { flex = 1 }),
        },
      })
      local layout = calculator:calculate(spec_2, viewport)
      assert.are.equal(45, layout.children[1].bounds.width)
      assert.are.equal(45, layout.children[2].bounds.width)
      assert.are.equal(55, layout.children[2].bounds.col) -- 45 + 10

      -- 5 children with 5px gaps
      local spec_5 = LayoutSpec.flex({
        direction = 'horizontal',
        gap = 5,
        children = {
          LayoutSpec.view(v1, { flex = 1 }),
          LayoutSpec.view(v2, { flex = 1 }),
          LayoutSpec.view(v3, { flex = 1 }),
          LayoutSpec.view(v4, { flex = 1 }),
          LayoutSpec.view(v5, { flex = 1 }),
        },
      })
      layout = calculator:calculate(spec_5, viewport)
      -- Total: 100, gaps: 4*5=20, available: 80, each: 16
      assert.are.equal(16, layout.children[1].bounds.width)
      assert.are.equal(0, layout.children[1].bounds.col)
      assert.are.equal(21, layout.children[2].bounds.col)
      assert.are.equal(84, layout.children[5].bounds.col)
    end)

    it('should handle vertical gaps', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.flex({
        direction = 'vertical',
        gap = 10,
        children = {
          LayoutSpec.view(v1, { flex = 1 }),
          LayoutSpec.view(v2, { flex = 1 }),
          LayoutSpec.view(v3, { flex = 1 }),
        },
      })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(0, layout.children[1].bounds.row)
      assert.are.equal(36, layout.children[2].bounds.row) -- 26 + 10
      assert.are.equal(72, layout.children[3].bounds.row) -- 26 + 10 + 26 + 10
    end)
  end)

  -- ============================================================================
  -- PERCENTAGES & CONSTRAINTS
  -- ============================================================================
  describe('Percentages and Constraints', function()
    it('should calculate percentages at multiple nesting levels', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 1000 })
      local leaf = { mount = function() end }

      local spec = LayoutSpec.absolute(
        LayoutSpec.absolute(LayoutSpec.view(leaf, { width = '50%', height = '50%' }), { width = '50%', height = '50%' }),
        { width = '80%', height = '80%' }
      )

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(800, layout.bounds.width)
      assert.are.equal(400, layout.children[1].bounds.width)
      assert.are.equal(200, layout.children[1].children[1].bounds.width)
    end)

    it('should enforce min/max constraints', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 100 })
      local v1, v2 = { mount = function() end }, { mount = function() end }

      -- Min constraint
      local spec_min = LayoutSpec.view(v1, { width = 10, min_width = 50 })
      local layout = calculator:calculate(spec_min, viewport)
      assert.are.equal(50, layout.bounds.width)

      -- Max constraint
      local spec_max = LayoutSpec.view(v1, { width = 500, max_width = 300 })
      layout = calculator:calculate(spec_max, viewport)
      assert.are.equal(300, layout.bounds.width)

      -- Max constraint in flex layout
      local spec_flex = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1, max_width = 400 }),
        LayoutSpec.view(v2, { flex = 1 }),
      })
      layout = calculator:calculate(spec_flex, viewport)
      assert.are.equal(400, layout.children[1].bounds.width)
      assert.are.equal(500, layout.children[2].bounds.width)
    end)
  end)

  -- ============================================================================
  -- ANCHOR POSITIONING (9 POSITIONS)
  -- ============================================================================
  describe('Anchor Positioning', function()
    it('should position at all 9 anchor points', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 800 })
      local v = { mount = function() end }
      local w, h = 200, 100

      local anchors = {
        ['top-left'] = { row = 0, col = 0 },
        ['top-center'] = { row = 0, col = 400 },
        ['top-right'] = { row = 0, col = 800 },
        ['center-left'] = { row = 350, col = 0 },
        ['center'] = { row = 350, col = 400 },
        ['center-right'] = { row = 350, col = 800 },
        ['bottom-left'] = { row = 700, col = 0 },
        ['bottom-center'] = { row = 700, col = 400 },
        ['bottom-right'] = { row = 700, col = 800 },
      }

      for anchor, expected in pairs(anchors) do
        local spec = LayoutSpec.absolute(LayoutSpec.view(v), { anchor = anchor, width = w, height = h })
        local layout = calculator:calculate(spec, viewport)
        assert.are.equal(expected.row, layout.bounds.row, string.format('anchor=%s row', anchor))
        assert.are.equal(expected.col, layout.bounds.col, string.format('anchor=%s col', anchor))
      end
    end)

    it('should apply offsets to anchored positions', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 800 })
      local v = { mount = function() end }

      local spec = LayoutSpec.absolute(
        LayoutSpec.view(v),
        { anchor = 'bottom-right', width = 200, height = 150, offset = { row = 20, col = 30 } }
      )

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(630, layout.bounds.row) -- 800 - 150 - 20
      assert.are.equal(770, layout.bounds.col) -- 1000 - 200 - 30
    end)
  end)

  -- ============================================================================
  -- COMPLEX NESTED LAYOUTS
  -- ============================================================================
  describe('Nested Layouts', function()
    it('should calculate 2x2 grid-like layout using nested flex', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 400, height = 200 })
      local nw, ne, sw, se =
        { mount = function() end }, { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.vertical({
        LayoutSpec.horizontal({
          LayoutSpec.view(nw, { flex = 1 }),
          LayoutSpec.view(ne, { flex = 1 }),
        }),
        LayoutSpec.horizontal({
          LayoutSpec.view(sw, { flex = 1 }),
          LayoutSpec.view(se, { flex = 1 }),
        }),
      })

      local layout = calculator:calculate(spec, viewport)

      -- NW quadrant
      assert.are.equal(0, layout.children[1].children[1].bounds.row)
      assert.are.equal(0, layout.children[1].children[1].bounds.col)
      assert.are.equal(200, layout.children[1].children[1].bounds.width)
      assert.are.equal(100, layout.children[1].children[1].bounds.height)

      -- SE quadrant
      assert.are.equal(100, layout.children[2].children[2].bounds.row)
      assert.are.equal(200, layout.children[2].children[2].bounds.col)
    end)

    it('should calculate header + split diff + footer', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 800, height = 600 })
      local header, left, right, footer =
        { mount = function() end }, { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.vertical({
        LayoutSpec.view(header, { height = 30 }),
        LayoutSpec.horizontal({
          LayoutSpec.view(left, { flex = 1 }),
          LayoutSpec.view(right, { flex = 1 }),
        }),
        LayoutSpec.view(footer, { height = 20 }),
      })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(30, layout.children[1].bounds.height)
      assert.are.equal(550, layout.children[2].children[1].bounds.height) -- 600 - 30 - 20
      assert.are.equal(400, layout.children[2].children[1].bounds.width)
      assert.are.equal(580, layout.children[3].bounds.row)
    end)

    it('should handle 4-level nesting (split with headers/footers in each pane)', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1200, height = 900 })
      local lh, ld, lf = { mount = function() end }, { mount = function() end }, { mount = function() end }
      local rh, rd, rf = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.vertical({
          LayoutSpec.view(lh, { height = 35 }),
          LayoutSpec.view(ld, { flex = 1 }),
          LayoutSpec.view(lf, { height = 20 }),
        }),
        LayoutSpec.vertical({
          LayoutSpec.view(rh, { height = 35 }),
          LayoutSpec.view(rd, { flex = 1 }),
          LayoutSpec.view(rf, { height = 20 }),
        }),
      })

      local layout = calculator:calculate(spec, viewport)

      -- Left pane
      assert.are.equal(600, layout.children[1].children[1].bounds.width)
      assert.are.equal(845, layout.children[1].children[2].bounds.height)

      -- Right pane
      assert.are.equal(600, layout.children[2].children[2].bounds.col)
    end)
  end)

  -- ============================================================================
  -- BOUNDS CREATION & UTILITY METHODS
  -- ============================================================================
  describe('LayoutBounds Creation and Utilities', function()
    it('should create bounds from viewport dimensions', function()
      local bounds = LayoutBounds.from_viewport()

      assert.are.equal(0, bounds.row)
      assert.are.equal(0, bounds.col)
      assert.are.equal(vim.o.columns, bounds.width)
      assert.are.equal(vim.o.lines, bounds.height)
      assert.is_nil(bounds.parent)
    end)

    it('should create bounds from current window', function()
      local win_id = vim.api.nvim_get_current_win()
      local expected_width = vim.api.nvim_win_get_width(win_id)
      local expected_height = vim.api.nvim_win_get_height(win_id)
      local expected_pos = vim.api.nvim_win_get_position(win_id)

      local bounds = LayoutBounds.from_window(win_id)

      assert.are.equal(expected_pos[1], bounds.row)
      assert.are.equal(expected_pos[2], bounds.col)
      assert.are.equal(expected_width, bounds.width)
      assert.are.equal(expected_height, bounds.height)
    end)

    it('should clone bounds correctly', function()
      local parent = LayoutBounds({ row = 5, col = 5, width = 100, height = 100 })
      local original = LayoutBounds({ row = 10, col = 20, width = 50, height = 60, parent = parent })

      local cloned = original:clone()

      assert.are.equal(original.row, cloned.row)
      assert.are.equal(original.col, cloned.col)
      assert.are.equal(original.width, cloned.width)
      assert.are.equal(original.height, cloned.height)
      assert.are.equal(original.parent, cloned.parent)
      assert.are_not.equal(original, cloned)
    end)

    it('should shrink bounds by margin', function()
      local bounds = LayoutBounds({ row = 10, col = 20, width = 100, height = 80 })

      local shrunken = bounds:shrink(5)

      assert.are.equal(15, shrunken.row)
      assert.are.equal(25, shrunken.col)
      assert.are.equal(90, shrunken.width)
      assert.are.equal(70, shrunken.height)
    end)

    it('should not shrink bounds below zero', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 5, height = 5 })

      local shrunken = bounds:shrink(10)

      assert.are.equal(0, shrunken.width)
      assert.are.equal(0, shrunken.height)
    end)

    it('should calculate available space for flex layouts', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 200, height = 150 })

      assert.are.equal(200, bounds:available_space('horizontal'))
      assert.are.equal(150, bounds:available_space('vertical'))
      assert.are.equal(0, bounds:available_space('invalid'))
    end)
  end)

  -- ============================================================================
  -- MODE-SPECIFIC CONTAINER BOUNDS
  -- ============================================================================
  describe('Mode-Specific Containers', function()
    it('should work with screen, popup, and lens mode bounds', function()
      local v1, v2 = { mount = function() end }, { mount = function() end }
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { flex = 1 }),
        LayoutSpec.view(v2, { flex = 1 }),
      })

      -- Screen mode: full viewport
      local screen_bounds = LayoutBounds({ row = 0, col = 0, width = 1920, height = 1080 })
      local screen_layout = calculator:calculate(spec, screen_bounds)
      assert.are.equal(960, screen_layout.children[1].bounds.width)
      assert.are.equal(1080, screen_layout.children[1].bounds.height)

      -- Popup mode: fixed size centered
      local popup_bounds = LayoutBounds({ row = 100, col = 100, width = 800, height = 600 })
      local popup_layout = calculator:calculate(spec, popup_bounds)
      assert.are.equal(400, popup_layout.children[1].bounds.width)
      assert.are.equal(600, popup_layout.children[1].bounds.height)
      assert.are.equal(100, popup_layout.children[1].bounds.row)

      -- Lens mode: full width at cursor
      local lens_bounds = LayoutBounds({ row = 20, col = 0, width = 1920, height = 400 })
      local lens_layout = calculator:calculate(spec, lens_bounds)
      assert.are.equal(960, lens_layout.children[1].bounds.width)
      assert.are.equal(400, lens_layout.children[1].bounds.height)
      assert.are.equal(20, lens_layout.children[1].bounds.row)
    end)

    it('should calculate centered popup precisely', function()
      local viewport = LayoutBounds.from_viewport()

      local popup_width, popup_height = 800, 600
      local expected_row = math.floor((viewport.height - popup_height) / 2)
      local expected_col = math.floor((viewport.width - popup_width) / 2)

      local popup_bounds = LayoutBounds({
        row = expected_row,
        col = expected_col,
        width = popup_width,
        height = popup_height,
      })

      local component = { mount = function() end }
      local spec = LayoutSpec.view(component, { flex = 1 })

      local layout = calculator:calculate(spec, popup_bounds)

      assert.are.equal(expected_row, layout.bounds.row)
      assert.are.equal(expected_col, layout.bounds.col)
      assert.are.equal(popup_width, layout.bounds.width)
      assert.are.equal(popup_height, layout.bounds.height)
    end)

    it('should split popup window precisely', function()
      local popup_bounds = LayoutBounds({ row = 100, col = 200, width = 1000, height = 800 })

      local prev, curr = { mount = function() end }, { mount = function() end }
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(prev, { flex = 1 }),
        LayoutSpec.view(curr, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, popup_bounds)

      assert.are.equal(100, layout.children[1].bounds.row)
      assert.are.equal(200, layout.children[1].bounds.col)
      assert.are.equal(500, layout.children[1].bounds.width)

      assert.are.equal(100, layout.children[2].bounds.row)
      assert.are.equal(700, layout.children[2].bounds.col)
      assert.are.equal(500, layout.children[2].bounds.width)
    end)
  end)

  -- ============================================================================
  -- LENS MODE CURSOR-RELATIVE POSITIONING
  -- ============================================================================
  describe('Lens Mode Cursor Positioning', function()
    it('should calculate lens bounds starting at cursor row', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 10 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = viewport.height - cursor_row,
      })

      assert.are.equal(9, lens_bounds.row)
      assert.are.equal(0, lens_bounds.col)
      assert.are.equal(viewport.width, lens_bounds.width)
      assert.are.equal(viewport.height - 9, lens_bounds.height)
    end)

    it('should position single component in lens bounds', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 15 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = 400,
      })

      local component = { mount = function() end }
      local spec = LayoutSpec.view(component, { flex = 1 })

      local layout = calculator:calculate(spec, lens_bounds)

      assert.are.equal(cursor_row, layout.bounds.row)
      assert.are.equal(0, layout.bounds.col)
      assert.are.equal(viewport.width, layout.bounds.width)
      assert.are.equal(400, layout.bounds.height)
    end)

    it('should position split components in lens bounds', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 20 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = 350,
      })

      local prev, curr = { mount = function() end }, { mount = function() end }
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(prev, { flex = 1 }),
        LayoutSpec.view(curr, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, lens_bounds)

      assert.are.equal(cursor_row, layout.children[1].bounds.row)
      assert.are.equal(0, layout.children[1].bounds.col)
      assert.are.equal(math.floor(viewport.width / 2), layout.children[1].bounds.width)
      assert.are.equal(350, layout.children[1].bounds.height)

      assert.are.equal(cursor_row, layout.children[2].bounds.row)
      assert.are.equal(math.floor(viewport.width / 2), layout.children[2].bounds.col)
      assert.are.equal(350, layout.children[2].bounds.height)
    end)

    it('should handle lens mode with header at cursor position', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 25 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = 400,
      })

      local header, body = { mount = function() end }, { mount = function() end }
      local spec = LayoutSpec.vertical({
        LayoutSpec.view(header, { height = 40 }),
        LayoutSpec.view(body, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, lens_bounds)

      assert.are.equal(cursor_row, layout.children[1].bounds.row)
      assert.are.equal(40, layout.children[1].bounds.height)

      assert.are.equal(cursor_row + 40, layout.children[2].bounds.row)
      assert.are.equal(360, layout.children[2].bounds.height)
    end)
  end)

  -- ============================================================================
  -- FLOAT WINDOW PLOT CONVERSIONS
  -- ============================================================================
  describe('Float Window Plot Conversions', function()
    it('should convert bounds to window plot with correct fields', function()
      local bounds = LayoutBounds({ row = 10, col = 20, width = 800, height = 600 })

      local plot = bounds:to_win_plot()

      assert.are.equal('editor', plot.relative)
      assert.are.equal(10, plot.row)
      assert.are.equal(20, plot.col)
      assert.are.equal(800, plot.width)
      assert.are.equal(600, plot.height)
      assert.are.equal('minimal', plot.style)
      assert.are.equal(2, plot.zindex)
      assert.is_true(plot.focusable)
    end)

    it('should respect custom window plot options', function()
      local bounds = LayoutBounds({ row = 5, col = 10, width = 400, height = 300 })

      local plot = bounds:to_win_plot({
        relative = 'cursor',
        zindex = 10,
        focusable = false,
        style = 'solid',
      })

      assert.are.equal('cursor', plot.relative)
      assert.are.equal(10, plot.zindex)
      assert.is_false(plot.focusable)
      assert.are.equal('solid', plot.style)
    end)

    it('should enforce minimum dimensions of 1x1', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 0, height = 0 })

      local plot = bounds:to_win_plot()

      assert.are.equal(1, plot.width)
      assert.are.equal(1, plot.height)
    end)

    it('should handle negative dimensions gracefully', function()
      local bounds = LayoutBounds({ row = 0, col = 0, width = -10, height = -5 })

      local plot = bounds:to_win_plot()

      assert.are.equal(1, plot.width)
      assert.are.equal(1, plot.height)
    end)
  end)

  -- ============================================================================
  -- DEEP NESTING PRECISION
  -- ============================================================================
  describe('Deep Nesting Precision', function()
    it('should handle 10-level deep nesting with percentages', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1024, height = 1024 })
      local leaf = { mount = function() end }

      local spec = LayoutSpec.view(leaf)
      for i = 1, 10 do
        spec = LayoutSpec.absolute(spec, { width = '50%', height = '50%' })
      end

      local layout = calculator:calculate(spec, viewport)

      -- Navigate to deepest level
      local current = layout
      for i = 1, 10 do
        current = current.children[1]
      end

      assert.are.equal(1, current.bounds.width)
      assert.are.equal(1, current.bounds.height)
    end)

    it('should maintain precision through 5 levels in lens mode', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 30 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = 500,
      })

      local leaf = { mount = function() end }

      local spec = LayoutSpec.vertical({
        LayoutSpec.view(leaf, { height = 30 }),
        LayoutSpec.horizontal({
          LayoutSpec.vertical({
            LayoutSpec.view(leaf, { height = 25 }),
            LayoutSpec.view(leaf, { flex = 1 }),
          }),
          LayoutSpec.vertical({
            LayoutSpec.view(leaf, { height = 25 }),
            LayoutSpec.view(leaf, { flex = 1 }),
          }),
        }),
      })

      local layout = calculator:calculate(spec, lens_bounds)

      -- Top header
      assert.are.equal(cursor_row, layout.children[1].bounds.row)
      assert.are.equal(30, layout.children[1].bounds.height)

      -- Split below header
      local split = layout.children[2]
      assert.are.equal(cursor_row + 30, split.bounds.row)
      assert.are.equal(470, split.bounds.height)

      -- Left pane
      local left_pane = split.children[1]
      assert.are.equal(cursor_row + 30, left_pane.bounds.row)
      assert.are.equal(math.floor(viewport.width / 2), left_pane.bounds.width)

      -- Left header
      assert.are.equal(cursor_row + 30, left_pane.children[1].bounds.row)
      assert.are.equal(25, left_pane.children[1].bounds.height)

      -- Left content
      assert.are.equal(cursor_row + 30 + 25, left_pane.children[2].bounds.row)
      assert.are.equal(445, left_pane.children[2].bounds.height)

      -- Right pane
      local right_pane = split.children[2]
      assert.are.equal(cursor_row + 30, right_pane.bounds.row)
      assert.are.equal(cursor_row + 30 + 25, right_pane.children[2].bounds.row)
      assert.are.equal(445, right_pane.children[2].bounds.height)
    end)

    it('should handle 10-level nesting with absolute positioning in lens', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 40 - 1

      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = 600,
      })

      local leaf = { mount = function() end }

      local spec = LayoutSpec.view(leaf)
      for i = 1, 10 do
        spec = LayoutSpec.absolute(spec, { width = '90%', height = '90%' })
      end

      local layout = calculator:calculate(spec, lens_bounds)

      -- Navigate each level and verify positioning
      local current = layout
      local expected_width = viewport.width
      local expected_height = 600

      for i = 1, 10 do
        local new_width = math.floor(expected_width * 0.9)
        local new_height = math.floor(expected_height * 0.9)

        assert.are.equal(new_width, current.bounds.width, string.format('Level %d width', i))
        assert.are.equal(new_height, current.bounds.height, string.format('Level %d height', i))

        expected_width = new_width
        expected_height = new_height

        if current.children and #current.children > 0 then
          current = current.children[1]
        else
          break
        end
      end
    end)
  end)

  -- ============================================================================
  -- VIEWPORT UNIT CONVERSIONS
  -- ============================================================================
  describe('Viewport Unit Conversions', function()
    it('should convert vh units relative to viewport height', function()
      local viewport = LayoutBounds.from_viewport()
      local bounds = LayoutBounds({ row = 0, col = 0, width = 100, height = viewport.height })

      local result = bounds:parse_dimension('50vh', nil, 'height')
      local expected = math.floor(vim.o.lines * 0.5)

      assert.are.equal(expected, result)
    end)

    it('should convert vw units relative to viewport width', function()
      local viewport = LayoutBounds.from_viewport()
      local bounds = LayoutBounds({ row = 0, col = 0, width = viewport.width, height = 100 })

      local result = bounds:parse_dimension('75vw', nil, 'width')
      local expected = math.floor(vim.o.columns * 0.75)

      assert.are.equal(expected, result)
    end)

    it('should handle vh/vw in lens mode layouts', function()
      local viewport = LayoutBounds.from_viewport()
      local cursor_row = 10 - 1

      local lens_height = math.floor(vim.o.lines * 0.35)
      local lens_bounds = LayoutBounds({
        row = cursor_row,
        col = 0,
        width = viewport.width,
        height = lens_height,
      })

      local component = { mount = function() end }
      local spec = LayoutSpec.view(component, { flex = 1 })

      local layout = calculator:calculate(spec, lens_bounds)

      assert.are.equal(lens_height, layout.bounds.height)
      assert.are.equal(cursor_row, layout.bounds.row)
    end)
  end)

  -- ============================================================================
  -- CHILD BOUNDS CALCULATION
  -- ============================================================================
  describe('Child LayoutBounds Calculation', function()
    it('should calculate child bounds with allocated space', function()
      local parent = LayoutBounds({ row = 100, col = 200, width = 1000, height = 800 })

      local allocated = { row = 150, col = 250, width = 500, height = 400 }
      local child = parent:child_bounds({}, allocated)

      assert.are.equal(150, child.row)
      assert.are.equal(250, child.col)
      assert.are.equal(500, child.width)
      assert.are.equal(400, child.height)
      assert.are.equal(parent, child.parent)
    end)

    it('should override allocated dimensions with explicit spec', function()
      local parent = LayoutBounds({ row = 0, col = 0, width = 1000, height = 800 })

      local allocated = { row = 0, col = 0, width = 500, height = 400 }
      local child = parent:child_bounds({ width = 300, height = 200 }, allocated)

      assert.are.equal(300, child.width)
      assert.are.equal(200, child.height)
    end)

    it('should apply anchor positioning to child bounds', function()
      local parent = LayoutBounds({ row = 0, col = 0, width = 1000, height = 800 })

      local child = parent:child_bounds({
        anchor = 'center',
        width = 200,
        height = 100,
      }, {})

      assert.are.equal(350, child.row)
      assert.are.equal(400, child.col)
      assert.are.equal(200, child.width)
      assert.are.equal(100, child.height)
    end)
  end)

  -- ============================================================================
  -- EDGE CASES & BOUNDARY CONDITIONS
  -- ============================================================================
  describe('Edge Cases', function()
    it('should handle zero and extreme dimensions', function()
      local v = { mount = function() end }

      -- Zero width
      local zero_w = LayoutBounds({ row = 0, col = 0, width = 0, height = 100 })
      local layout = calculator:calculate(LayoutSpec.view(v, { flex = 1 }), zero_w)
      assert.are.equal(0, layout.bounds.width)

      -- Very large dimensions
      local huge = LayoutBounds({ row = 0, col = 0, width = 999999, height = 999999 })
      layout = calculator:calculate(LayoutSpec.view(v, { width = '50%', height = '50%' }), huge)
      assert.are.equal(499999, layout.bounds.width)
    end)

    it('should handle many children without losing pixels', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 100 })

      local children = {}
      for i = 1, 7 do
        children[i] = LayoutSpec.view({ mount = function() end }, { flex = 1 })
      end

      local spec = LayoutSpec.horizontal(children)
      local layout = calculator:calculate(spec, viewport)

      local total = 0
      for i = 1, 7 do
        total = total + layout.children[i].bounds.width
      end

      assert.are.equal(1000, total)
    end)
  end)

  -- ============================================================================
  -- ERROR HANDLING & VALIDATION
  -- ============================================================================
  describe('Error Handling', function()
    it('should error on missing spec', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })

      assert.has_error(function()
        calculator:calculate(nil, viewport)
      end, 'LayoutCalculator:calculate() requires a spec')
    end)

    it('should error on unknown layout type', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local bad_spec = { type = 'UNKNOWN_TYPE' }

      assert.has_error(function()
        calculator:calculate(bad_spec, viewport)
      end)
    end)
  end)

  -- ============================================================================
  -- EMPTY LAYOUTS
  -- ============================================================================
  describe('Empty Layouts', function()
    it('should handle empty flex container', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })

      local spec = LayoutSpec.horizontal({}) -- No children
      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(0, #layout.children)
      assert.are.equal(viewport.width, layout.bounds.width)
      assert.are.equal(viewport.height, layout.bounds.height)
    end)

    it('should handle nil children array gracefully', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })

      local spec = { type = LayoutSpec.Type.FLEX, direction = 'horizontal', children = nil }
      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(0, #layout.children)
    end)
  end)

  -- ============================================================================
  -- OVERFLOW SCENARIOS
  -- ============================================================================
  describe('Overflow Scenarios', function()
    it('should handle overflow when fixed sizes exceed available space', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2 = { mount = function() end }, { mount = function() end }

      -- Fixed sizes total 150, available is 100
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { width = 80 }),
        LayoutSpec.view(v2, { width = 70 }),
      })

      local layout = calculator:calculate(spec, viewport)

      -- Fixed children keep their sizes, flex space becomes 0
      assert.are.equal(80, layout.children[1].bounds.width)
      assert.are.equal(70, layout.children[2].bounds.width)
    end)

    it('should handle fixed + flex overflow gracefully', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2, v3 = { mount = function() end }, { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(v1, { width = 60 }),
        LayoutSpec.view(v2, { width = 50 }),
        LayoutSpec.view(v3, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(60, layout.children[1].bounds.width)
      assert.are.equal(50, layout.children[2].bounds.width)
      assert.are.equal(0, layout.children[3].bounds.width) -- No space left
    end)

    it('should handle gaps causing overflow', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 100, height = 100 })
      local v1, v2 = { mount = function() end }, { mount = function() end }

      -- Gap of 50 + two children = overflow
      local spec = LayoutSpec.flex({
        direction = 'horizontal',
        gap = 50,
        children = {
          LayoutSpec.view(v1, { flex = 1 }),
          LayoutSpec.view(v2, { flex = 1 }),
        },
      })

      local layout = calculator:calculate(spec, viewport)

      -- Available space = 100 - 50 = 50, split between 2 = 25 each
      assert.are.equal(25, layout.children[1].bounds.width)
      assert.are.equal(25, layout.children[2].bounds.width)
    end)
  end)

  -- ============================================================================
  -- DIRECT POSITIONING
  -- ============================================================================
  describe('Direct Row/Col Positioning', function()
    it('should support direct row/col without anchors', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 1000 })
      local v = { mount = function() end }

      local spec = LayoutSpec.absolute(LayoutSpec.view(v), { row = 100, col = 200, width = 300, height = 150 })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(100, layout.bounds.row)
      assert.are.equal(200, layout.bounds.col)
      assert.are.equal(300, layout.bounds.width)
      assert.are.equal(150, layout.bounds.height)
    end)

    it('should combine row/col with percentage dimensions', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 800 })
      local v = { mount = function() end }

      local spec = LayoutSpec.absolute(LayoutSpec.view(v), { row = 50, col = 100, width = '50%', height = '25%' })

      local layout = calculator:calculate(spec, viewport)

      assert.are.equal(50, layout.bounds.row)
      assert.are.equal(100, layout.bounds.col)
      assert.are.equal(500, layout.bounds.width)
      assert.are.equal(200, layout.bounds.height)
    end)

    it('should support relative positioning in nested layouts', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 1000 })
      local v1, v2 = { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.absolute(
        LayoutSpec.absolute(LayoutSpec.view(v1), { row = 50, col = 50, width = 200, height = 200 }),
        { row = 100, col = 100, width = 500, height = 500 }
      )

      local layout = calculator:calculate(spec, viewport)

      -- Outer absolute
      assert.are.equal(100, layout.bounds.row)
      assert.are.equal(100, layout.bounds.col)

      -- Inner absolute (relative to parent)
      assert.are.equal(150, layout.children[1].bounds.row) -- 100 + 50
      assert.are.equal(150, layout.children[1].bounds.col) -- 100 + 50
    end)
  end)

  -- ============================================================================
  -- REAL-WORLD COMPONENT SCENARIOS
  -- ============================================================================
  describe('Real-World Scenarios', function()
    it('should calculate DiffScreen layout (unified and split)', function()
      local viewport = LayoutBounds({ row = 0, col = 0, width = 1920, height = 1080 })
      local prev, curr = { mount = function() end }, { mount = function() end }

      -- Unified: single pane
      local unified = LayoutSpec.view(prev, { flex = 1 })
      local layout = calculator:calculate(unified, viewport)
      assert.are.equal(1920, layout.bounds.width)
      assert.are.equal(1080, layout.bounds.height)

      -- Split: two panes side by side
      local split = LayoutSpec.horizontal({
        LayoutSpec.view(prev, { flex = 1 }),
        LayoutSpec.view(curr, { flex = 1 }),
      })
      layout = calculator:calculate(split, viewport)
      assert.are.equal(960, layout.children[1].bounds.width)
      assert.are.equal(960, layout.children[2].bounds.width)
    end)

    it('should calculate HunkLens layout with split', function()
      local cursor_row = 20
      local lens_bounds = LayoutBounds({ row = cursor_row, col = 0, width = 1920, height = 378 })
      local prev, curr = { mount = function() end }, { mount = function() end }

      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(prev, { flex = 1 }),
        LayoutSpec.view(curr, { flex = 1 }),
      })

      local layout = calculator:calculate(spec, lens_bounds)

      assert.are.equal(960, layout.children[1].bounds.width)
      assert.are.equal(378, layout.children[1].bounds.height)
      assert.are.equal(cursor_row, layout.children[1].bounds.row)
      assert.are.equal(960, layout.children[2].bounds.col)
    end)
  end)

  -- ============================================================================
  -- UNIFIED & SPLIT DIFF COMPONENT SUPPORT
  -- ============================================================================
  describe('Unified and Split Diff Components', function()
    -- ========================================
    -- UNIFIED DIFF MODE
    -- ========================================
    describe('UnifiedDiffComponent', function()
      it('should support unified diff in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local diff_content = { mount = function() end }

        -- Simple unified view - single pane
        local spec = LayoutSpec.view(diff_content, { flex = 1 })
        local layout = calculator:calculate(spec, viewport)

        assert.are.equal(0, layout.bounds.row)
        assert.are.equal(0, layout.bounds.col)
        assert.are.equal(viewport.width, layout.bounds.width)
        assert.are.equal(viewport.height, layout.bounds.height)
      end)

      it('should support unified diff with header in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local header = { mount = function() end }
        local diff_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.view(diff_content, { flex = 1 }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Header
        assert.are.equal(0, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)
        assert.are.equal(viewport.width, layout.children[1].bounds.width)

        -- Content
        assert.are.equal(3, layout.children[2].bounds.row)
        assert.are.equal(viewport.height - 3, layout.children[2].bounds.height)
      end)

      it('should support unified diff with header and footer in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local header = { mount = function() end }
        local diff_content = { mount = function() end }
        local footer = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.view(diff_content, { flex = 1 }),
          LayoutSpec.view(footer, { height = 2 }),
        })

        local layout = calculator:calculate(spec, viewport)

        assert.are.equal(0, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)
        assert.are.equal(viewport.height - 5, layout.children[2].bounds.height)
        assert.are.equal(viewport.height - 2, layout.children[3].bounds.row)
      end)

      it('should support unified diff in popup mode', function()
        local viewport = LayoutBounds.from_viewport()
        local popup_width, popup_height = 800, 600
        local popup_row = math.floor((viewport.height - popup_height) / 2)
        local popup_col = math.floor((viewport.width - popup_width) / 2)

        local popup_bounds = LayoutBounds({
          row = popup_row,
          col = popup_col,
          width = popup_width,
          height = popup_height,
        })

        local header = { mount = function() end }
        local diff_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.view(diff_content, { flex = 1 }),
        })

        local layout = calculator:calculate(spec, popup_bounds)

        assert.are.equal(popup_row, layout.children[1].bounds.row)
        assert.are.equal(popup_col, layout.children[1].bounds.col)
        assert.are.equal(800, layout.children[1].bounds.width)
        assert.are.equal(3, layout.children[1].bounds.height)
        assert.are.equal(597, layout.children[2].bounds.height)
      end)

      it('should support unified diff in lens mode', function()
        local viewport = LayoutBounds.from_viewport()
        local cursor_row = 15 - 1

        local lens_bounds = LayoutBounds({
          row = cursor_row,
          col = 0,
          width = viewport.width,
          height = 400,
        })

        local header = { mount = function() end }
        local diff_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.view(diff_content, { flex = 1 }),
        })

        local layout = calculator:calculate(spec, lens_bounds)

        -- Header at cursor row
        assert.are.equal(cursor_row, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)

        -- Content below header
        assert.are.equal(cursor_row + 3, layout.children[2].bounds.row)
        assert.are.equal(397, layout.children[2].bounds.height)
      end)
    end)

    -- ========================================
    -- SPLIT DIFF MODE
    -- ========================================
    describe('SplitDiffComponent', function()
      it('should support split diff in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        -- Simple split - two side-by-side panes
        local spec = LayoutSpec.horizontal({
          LayoutSpec.view(prev_content, { flex = 1 }),
          LayoutSpec.view(curr_content, { flex = 1 }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Left pane
        assert.are.equal(0, layout.children[1].bounds.row)
        assert.are.equal(0, layout.children[1].bounds.col)
        assert.are.equal(math.floor(viewport.width / 2), layout.children[1].bounds.width)
        assert.are.equal(viewport.height, layout.children[1].bounds.height)

        -- Right pane
        assert.are.equal(0, layout.children[2].bounds.row)
        assert.are.equal(math.floor(viewport.width / 2), layout.children[2].bounds.col)
        assert.are.equal(viewport.height, layout.children[2].bounds.height)
      end)

      it('should support split diff with shared header in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local header = { mount = function() end }
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.horizontal({
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Shared header
        assert.are.equal(0, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)
        assert.are.equal(viewport.width, layout.children[1].bounds.width)

        -- Split panes
        local split = layout.children[2]
        assert.are.equal(3, split.bounds.row)
        assert.are.equal(viewport.height - 3, split.bounds.height)

        -- Left pane
        assert.are.equal(3, split.children[1].bounds.row)
        assert.are.equal(viewport.height - 3, split.children[1].bounds.height)

        -- Right pane
        assert.are.equal(3, split.children[2].bounds.row)
        assert.are.equal(viewport.height - 3, split.children[2].bounds.height)
      end)

      it('should support split diff with shared header and footer in screen mode', function()
        local viewport = LayoutBounds.from_viewport()
        local header = { mount = function() end }
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }
        local footer = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.horizontal({
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          }),
          LayoutSpec.view(footer, { height = 2 }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Header
        assert.are.equal(0, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)

        -- Split panes
        local split = layout.children[2]
        assert.are.equal(3, split.bounds.row)
        assert.are.equal(viewport.height - 5, split.bounds.height)

        -- Footer
        assert.are.equal(viewport.height - 2, layout.children[3].bounds.row)
        assert.are.equal(2, layout.children[3].bounds.height)
      end)

      it('should support split diff with individual headers in each pane', function()
        local viewport = LayoutBounds.from_viewport()
        local prev_header = { mount = function() end }
        local prev_content = { mount = function() end }
        local curr_header = { mount = function() end }
        local curr_content = { mount = function() end }

        local spec = LayoutSpec.horizontal({
          LayoutSpec.vertical({
            LayoutSpec.view(prev_header, { height = 3 }),
            LayoutSpec.view(prev_content, { flex = 1 }),
          }),
          LayoutSpec.vertical({
            LayoutSpec.view(curr_header, { height = 3 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Left pane header
        assert.are.equal(0, layout.children[1].children[1].bounds.row)
        assert.are.equal(3, layout.children[1].children[1].bounds.height)

        -- Left pane content
        assert.are.equal(3, layout.children[1].children[2].bounds.row)
        assert.are.equal(viewport.height - 3, layout.children[1].children[2].bounds.height)

        -- Right pane header
        assert.are.equal(0, layout.children[2].children[1].bounds.row)
        assert.are.equal(3, layout.children[2].children[1].bounds.height)

        -- Right pane content
        assert.are.equal(3, layout.children[2].children[2].bounds.row)
        assert.are.equal(viewport.height - 3, layout.children[2].children[2].bounds.height)
      end)

      it('should support split diff with headers and footers in each pane', function()
        local viewport = LayoutBounds.from_viewport()
        local prev_header = { mount = function() end }
        local prev_content = { mount = function() end }
        local prev_footer = { mount = function() end }
        local curr_header = { mount = function() end }
        local curr_content = { mount = function() end }
        local curr_footer = { mount = function() end }

        local spec = LayoutSpec.horizontal({
          LayoutSpec.vertical({
            LayoutSpec.view(prev_header, { height = 3 }),
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(prev_footer, { height = 2 }),
          }),
          LayoutSpec.vertical({
            LayoutSpec.view(curr_header, { height = 3 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
            LayoutSpec.view(curr_footer, { height = 2 }),
          }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Left pane
        assert.are.equal(0, layout.children[1].children[1].bounds.row)
        assert.are.equal(3, layout.children[1].children[1].bounds.height)
        assert.are.equal(viewport.height - 5, layout.children[1].children[2].bounds.height)
        assert.are.equal(viewport.height - 2, layout.children[1].children[3].bounds.row)

        -- Right pane
        assert.are.equal(0, layout.children[2].children[1].bounds.row)
        assert.are.equal(3, layout.children[2].children[1].bounds.height)
        assert.are.equal(viewport.height - 5, layout.children[2].children[2].bounds.height)
        assert.are.equal(viewport.height - 2, layout.children[2].children[3].bounds.row)
      end)

      it('should support split diff in popup mode', function()
        local viewport = LayoutBounds.from_viewport()
        local popup_width, popup_height = 1000, 700
        local popup_row = math.floor((viewport.height - popup_height) / 2)
        local popup_col = math.floor((viewport.width - popup_width) / 2)

        local popup_bounds = LayoutBounds({
          row = popup_row,
          col = popup_col,
          width = popup_width,
          height = popup_height,
        })

        local header = { mount = function() end }
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.horizontal({
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          }),
        })

        local layout = calculator:calculate(spec, popup_bounds)

        -- Header
        assert.are.equal(popup_row, layout.children[1].bounds.row)
        assert.are.equal(1000, layout.children[1].bounds.width)
        assert.are.equal(3, layout.children[1].bounds.height)

        -- Split panes
        local split = layout.children[2]
        assert.are.equal(popup_row + 3, split.bounds.row)
        assert.are.equal(697, split.bounds.height)

        -- Left pane
        assert.are.equal(popup_col, split.children[1].bounds.col)
        assert.are.equal(500, split.children[1].bounds.width)

        -- Right pane
        assert.are.equal(popup_col + 500, split.children[2].bounds.col)
        assert.are.equal(500, split.children[2].bounds.width)
      end)

      it('should support split diff in lens mode', function()
        local viewport = LayoutBounds.from_viewport()
        local cursor_row = 20 - 1

        local lens_bounds = LayoutBounds({
          row = cursor_row,
          col = 0,
          width = viewport.width,
          height = 450,
        })

        local header = { mount = function() end }
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        local spec = LayoutSpec.vertical({
          LayoutSpec.view(header, { height = 3 }),
          LayoutSpec.horizontal({
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          }),
        })

        local layout = calculator:calculate(spec, lens_bounds)

        -- Header at cursor row
        assert.are.equal(cursor_row, layout.children[1].bounds.row)
        assert.are.equal(3, layout.children[1].bounds.height)

        -- Split panes below header
        local split = layout.children[2]
        assert.are.equal(cursor_row + 3, split.bounds.row)
        assert.are.equal(447, split.bounds.height)

        -- Left pane
        assert.are.equal(cursor_row + 3, split.children[1].bounds.row)
        assert.are.equal(math.floor(viewport.width / 2), split.children[1].bounds.width)
        assert.are.equal(447, split.children[1].bounds.height)

        -- Right pane
        assert.are.equal(cursor_row + 3, split.children[2].bounds.row)
        assert.are.equal(math.floor(viewport.width / 2), split.children[2].bounds.col)
        assert.are.equal(447, split.children[2].bounds.height)
      end)

      it('should support split diff with unequal flex ratios', function()
        local viewport = LayoutBounds({ row = 0, col = 0, width = 1200, height = 800 })
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        -- 1:2 ratio - current gets more space
        local spec = LayoutSpec.horizontal({
          LayoutSpec.view(prev_content, { flex = 1 }),
          LayoutSpec.view(curr_content, { flex = 2 }),
        })

        local layout = calculator:calculate(spec, viewport)

        -- Left pane (1/3 of width)
        assert.are.equal(400, layout.children[1].bounds.width)

        -- Right pane (2/3 of width)
        assert.are.equal(800, layout.children[2].bounds.width)
        assert.are.equal(400, layout.children[2].bounds.col)
      end)

      it('should support split diff with gap between panes', function()
        local viewport = LayoutBounds({ row = 0, col = 0, width = 1000, height = 600 })
        local prev_content = { mount = function() end }
        local curr_content = { mount = function() end }

        local spec = LayoutSpec.flex({
          direction = 'horizontal',
          gap = 2,
          children = {
            LayoutSpec.view(prev_content, { flex = 1 }),
            LayoutSpec.view(curr_content, { flex = 1 }),
          },
        })

        local layout = calculator:calculate(spec, viewport)

        -- Left pane (499 pixels)
        assert.are.equal(0, layout.children[1].bounds.col)
        assert.are.equal(499, layout.children[1].bounds.width)

        -- Right pane (499 pixels, starting at 501)
        assert.are.equal(501, layout.children[2].bounds.col)
        assert.are.equal(499, layout.children[2].bounds.width)
      end)
    end)
  end)
end)
