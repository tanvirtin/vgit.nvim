local eq = assert.are.same
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

describe('LayoutRenderer:', function()
  local LayoutRenderer

  before_each(function()
    LayoutRenderer = require('vgit.ui.layout.LayoutRenderer')
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
        is_screen_mode = function() return false end,
        is_lens_mode = function() return false end,
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
        is_screen_mode = function() return false end,
        is_lens_mode = function() return false end,
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
        is_screen_mode = function() return false end,
        is_lens_mode = function() return false end,
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
end)
