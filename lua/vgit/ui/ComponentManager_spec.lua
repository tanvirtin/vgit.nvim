local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

-- We only test parse_layout_spec in isolation.
-- ComponentManager requires LayoutRenderer for render(), which needs real Neovim UI.
-- We construct a ComponentManager manually, bypassing the full constructor to avoid
-- requiring LayoutContext/LayoutRenderer at construction time.

local Object = require('vgit.core.Object')
local ComponentGroup = require('vgit.ui.ComponentGroup')

local eq = assert.are.same

-- Create a minimal ComponentManager-like object that has parse_layout_spec
-- but avoids requiring the full module (which imports LayoutRenderer/LayoutContext at load time).
local function create_manager()
  local ComponentManager = require('vgit.ui.ComponentManager')
  local mgr = ComponentManager()
  return mgr
end

local function mock_child_component(layout_spec, opts)
  opts = opts or {}
  return {
    mounted = opts.mounted or false,
    props = {},
    get_layout_spec = function()
      return layout_spec
    end,
    mount = function(self)
      self.mounted = true
    end,
    unmount = function(self)
      self.mounted = false
    end,
    component_did_mount = function() end,
    on = function() end,
    set_keymap = function() end,
  }
end

describe('ComponentManager:', function()
  local mgr

  before_each(function()
    mgr = create_manager()
  end)

  describe('parse_layout_spec', function()
    it('should return a spec with type unchanged when no children', function()
      local spec = {
        type = LayoutSpec.Type.FLEX,
        direction = 'horizontal',
        children = {},
      }
      local result = mgr:parse_layout_spec(spec)
      assert.are.equal(LayoutSpec.Type.FLEX, result.type)
      eq({}, result.children)
    end)

    it('should mount child components found in children array', function()
      local child_view = mock_child_component({
        type = LayoutSpec.Type.VIEW,
        view = {},
      })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(child_view, { id = 'test', flex = 1 }),
      })
      mgr:parse_layout_spec(spec)
      assert.is_true(child_view.mounted)
    end)

    it('should skip already mounted child components', function()
      local mount_count = 0
      local child_view = mock_child_component({
        type = LayoutSpec.Type.VIEW,
        view = {},
      }, { mounted = true })
      local original_mount = child_view.mount
      child_view.mount = function(self)
        mount_count = mount_count + 1
        original_mount(self)
      end
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(child_view, { id = 'test', flex = 1 }),
      })
      mgr:parse_layout_spec(spec)
      assert.are.equal(0, mount_count)
    end)

    it('should replace child spec with parsed child layout spec', function()
      local inner_spec = {
        type = LayoutSpec.Type.VIEW,
        view = { some = 'element' },
        id = 'inner',
        flex = 1,
      }
      local child_view = mock_child_component(inner_spec)
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(child_view, { id = 'wrapper', flex = 1 }),
      })
      local result = mgr:parse_layout_spec(spec)
      -- The child should have been replaced with the inner spec
      assert.are.equal(LayoutSpec.Type.VIEW, result.children[1].type)
      assert.are.equal('inner', result.children[1].id)
    end)

    it('should mount single child component via child property', function()
      local child_view = mock_child_component({
        type = LayoutSpec.Type.VIEW,
        view = {},
      })
      local spec = LayoutSpec.container(LayoutSpec.view(child_view, { id = 'c', flex = 1 }))
      -- container has type + child
      -- The child is a VIEW with child_view as view
      mgr:parse_layout_spec(spec)
      assert.is_true(child_view.mounted)
    end)

    it('should handle nested layout specs recursively', function()
      local inner_child = mock_child_component({
        type = LayoutSpec.Type.VIEW,
        view = {},
      })
      -- Create a component whose layout spec itself contains children
      local outer_spec = LayoutSpec.horizontal({
        LayoutSpec.view(inner_child, { id = 'deep', flex = 1 }),
      })
      local outer_child = mock_child_component(outer_spec)
      local spec = LayoutSpec.container(LayoutSpec.view(outer_child, { id = 'outer', flex = 1 }))
      mgr:parse_layout_spec(spec)
      assert.is_true(outer_child.mounted)
      assert.is_true(inner_child.mounted)
    end)

    it('should wrap spec with win_plot in container/view', function()
      local spec = {
        plot = {
          win_plot = { width = 100, height = 50, row = 0, col = 0, relative = 'editor' },
        },
      }
      local result = mgr:parse_layout_spec(spec)
      assert.are.equal(LayoutSpec.Type.CONTAINER, result.type)
      assert.is_not_nil(result.child)
      assert.are.equal(LayoutSpec.Type.VIEW, result.child.type)
      assert.are.equal('element', result.child.id)
    end)

    it('should delegate to inner layout when spec has layout property', function()
      local inner = {
        type = LayoutSpec.Type.FLEX,
        direction = 'vertical',
        children = {},
      }
      local spec = { layout = inner }
      local result = mgr:parse_layout_spec(spec)
      assert.are.equal(LayoutSpec.Type.FLEX, result.type)
      assert.are.equal('vertical', result.direction)
    end)

    it('should wrap plain table in container/view', function()
      local spec = { some_field = 'value' }
      local result = mgr:parse_layout_spec(spec)
      assert.are.equal(LayoutSpec.Type.CONTAINER, result.type)
      assert.is_not_nil(result.child)
      assert.are.equal(LayoutSpec.Type.VIEW, result.child.type)
      assert.are.equal('pane', result.child.id)
    end)

    it('should error on nil input', function()
      assert.has_error(function()
        mgr:parse_layout_spec(nil)
      end, 'Unable to convert UI description to LayoutSpec')
    end)
  end)
end)
