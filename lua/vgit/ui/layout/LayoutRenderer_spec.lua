local eq = assert.are.same
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local Element = require('vgit.ui.elements.Element')
local LayoutContext = require('vgit.ui.layout.LayoutContext')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')
local ui_helper = require('tests.helpers.ui')
local cleanup_ui = ui_helper.cleanup_ui
local count_floating_windows = ui_helper.count_floating_windows

describe('LayoutRenderer:', function()
  local LayoutRenderer

  before_each(function()
    LayoutRenderer = require('vgit.ui.layout.LayoutRenderer')
  end)

  after_each(function()
    cleanup_ui()
  end)

  describe('constructor', function()
    it('should error when context is nil', function()
      assert.has_error(function()
        LayoutRenderer(nil)
      end, 'LayoutRenderer requires LayoutContext')
    end)

    it('should create with valid context', function()
      local context = {
        create_parent_bounds = function() end,
        is_screen_mode = function()
          return false
        end,
        is_lens_mode = function()
          return false
        end,
      }
      local renderer = LayoutRenderer(context)

      assert.is_not_nil(renderer)
      eq(context, renderer.context)
      assert.is_table(renderer.windows)
      eq(0, renderer.window_index)
    end)
  end)

  describe('render_layout', function()
    local function make_context()
      return {
        create_parent_bounds = function() end,
        is_screen_mode = function()
          return false
        end,
        is_lens_mode = function()
          return false
        end,
        mode = 'popup',
      }
    end

    it('should dispatch to render_container_layout for CONTAINER type', function()
      local renderer = LayoutRenderer(make_context())
      local dispatched = false

      renderer.render_container_layout = function(_, layout)
        dispatched = true
      end

      renderer:render_layout({
        spec = { type = LayoutSpec.Type.CONTAINER },
        children = {},
      })

      assert.is_true(dispatched)
    end)

    it('should dispatch to render_container_layout for FLEX type', function()
      local renderer = LayoutRenderer(make_context())
      local dispatched = false

      renderer.render_container_layout = function(_, layout)
        dispatched = true
      end

      renderer:render_layout({
        spec = { type = LayoutSpec.Type.FLEX },
        children = {},
      })

      assert.is_true(dispatched)
    end)

    it('should dispatch to render_absolute_layout for ABSOLUTE type', function()
      local renderer = LayoutRenderer(make_context())
      local dispatched = false

      renderer.render_absolute_layout = function(_, layout)
        dispatched = true
      end

      renderer:render_layout({
        spec = { type = LayoutSpec.Type.ABSOLUTE },
        children = {},
      })

      assert.is_true(dispatched)
    end)

    it('should dispatch to render_view_layout for VIEW type', function()
      local renderer = LayoutRenderer(make_context())
      local dispatched = false

      renderer.render_view_layout = function(_, layout)
        dispatched = true
      end

      renderer:render_layout({
        spec = { type = LayoutSpec.Type.VIEW },
      })

      assert.is_true(dispatched)
    end)

    it('should return nil for unknown type', function()
      local renderer = LayoutRenderer(make_context())

      local result = renderer:render_layout({
        spec = { type = 'unknown' },
      })

      assert.is_nil(result)
    end)
  end)

  describe('render_container_layout', function()
    it('should recursively render children', function()
      local context = {
        create_parent_bounds = function() end,
        is_screen_mode = function()
          return false
        end,
        is_lens_mode = function()
          return false
        end,
      }
      local renderer = LayoutRenderer(context)
      local rendered_children = {}

      renderer.render_layout = function(_, child)
        table.insert(rendered_children, child)
      end

      local children = {
        { spec = { type = 'view' } },
        { spec = { type = 'view' } },
      }

      renderer:render_container_layout({ children = children })

      eq(2, #rendered_children)
    end)
  end)

  describe('render_view_layout (real UI)', function()
    it('should mount element with real floating window', function()
      local element = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local bounds = LayoutBounds({
        row = 2,
        col = 2,
        width = 30,
        height = 10,
      })

      local renderer = LayoutRenderer(context)
      renderer:render_view_layout({
        spec = {
          type = LayoutSpec.Type.VIEW,
          view = element,
          zindex = 2,
        },
        bounds = bounds,
      })

      assert.is_true(element._mounted)
      assert.is_true(element:is_valid())
      assert.is_true(vim.api.nvim_win_is_valid(element:get_win_id()))
    end)

    it('should set window_mode from context mode', function()
      local element = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local bounds = LayoutBounds({
        row = 0,
        col = 0,
        width = 30,
        height = 10,
      })

      local renderer = LayoutRenderer(context)
      renderer:render_view_layout({
        spec = {
          type = LayoutSpec.Type.VIEW,
          view = element,
          zindex = 2,
        },
        bounds = bounds,
      })

      assert.are.equal('popup', element._config.window_mode)
    end)

    it('should update _plot.win_plot from calculated bounds', function()
      local element = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local bounds = LayoutBounds({
        row = 3,
        col = 5,
        width = 25,
        height = 8,
      })

      local renderer = LayoutRenderer(context)
      renderer:render_view_layout({
        spec = {
          type = LayoutSpec.Type.VIEW,
          view = element,
          zindex = 2,
        },
        bounds = bounds,
      })

      assert.are.equal(3, element._plot.win_plot.row)
      assert.are.equal(5, element._plot.win_plot.col)
      assert.are.equal(25, element._plot.win_plot.width)
      assert.are.equal(8, element._plot.win_plot.height)
    end)

    it('should close window after element unmount', function()
      local element = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local bounds = LayoutBounds({
        row = 0,
        col = 0,
        width = 30,
        height = 10,
      })

      local renderer = LayoutRenderer(context)
      renderer:render_view_layout({
        spec = {
          type = LayoutSpec.Type.VIEW,
          view = element,
          zindex = 2,
        },
        bounds = bounds,
      })

      assert.is_true(count_floating_windows() >= 1)

      element:unmount()
      assert.are.equal(0, count_floating_windows())
    end)
  end)

  describe('render (end-to-end)', function()
    it('should render container wrapping a view with real window', function()
      local element = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local spec = LayoutSpec.container(LayoutSpec.view(element, { flex = 1 }))
      local renderer = LayoutRenderer(context)
      renderer:render(spec)

      assert.is_true(element._mounted)
      assert.is_true(element:is_valid())
      assert.is_true(count_floating_windows() >= 1)
    end)

    it('should render multiple views via render_layout', function()
      local element1 = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })
      local element2 = Element({
        win_plot = {
          relative = 'editor',
          width = 20,
          height = 5,
          row = 0,
          col = 0,
          style = 'minimal',
        },
      })

      local context = LayoutContext({
        mode = 'popup',
        width = 40,
        height = 20,
      })

      local bounds1 = LayoutBounds({ row = 0, col = 0, width = 20, height = 10 })
      local bounds2 = LayoutBounds({ row = 0, col = 20, width = 20, height = 10 })

      local renderer = LayoutRenderer(context)

      -- Render two views directly via render_layout with pre-calculated bounds
      renderer:render_layout({
        spec = { type = LayoutSpec.Type.CONTAINER },
        children = {
          {
            spec = { type = LayoutSpec.Type.VIEW, view = element1, zindex = 2 },
            bounds = bounds1,
          },
          {
            spec = { type = LayoutSpec.Type.VIEW, view = element2, zindex = 2 },
            bounds = bounds2,
          },
        },
      })

      assert.is_true(element1._mounted)
      assert.is_true(element2._mounted)
      assert.is_true(element1:is_valid())
      assert.is_true(element2:is_valid())
      assert.is_true(count_floating_windows() >= 2)
      assert.is_true(element1:get_width() > 0)
      assert.is_true(element2:get_width() > 0)
    end)
  end)
end)
