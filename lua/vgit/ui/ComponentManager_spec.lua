local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local ComponentManager = require('vgit.ui.ComponentManager')
local ui_helper = require('tests.helpers.ui')
local TestComponent = ui_helper.TestComponent
local cleanup_ui = ui_helper.cleanup_ui
local count_floating_windows = ui_helper.count_floating_windows

local eq = assert.are.same

local function create_manager()
  return ComponentManager()
end

describe('ComponentManager:', function()
  local mgr

  before_each(function()
    mgr = create_manager()
  end)

  after_each(function()
    cleanup_ui()
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
      local child_view = TestComponent({ name = 'child' })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(child_view, { id = 'test', flex = 1 }),
      })
      mgr:parse_layout_spec(spec)
      assert.is_true(child_view._mounted)
    end)

    it('should skip already mounted child components', function()
      local child_view = TestComponent({ name = 'child' })
      child_view._mounted = true
      local mount_count = 0
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
      local child_view = TestComponent({ name = 'child' })
      local spec = LayoutSpec.horizontal({
        LayoutSpec.view(child_view, { id = 'wrapper', flex = 1 }),
      })
      local result = mgr:parse_layout_spec(spec)
      -- The child should have been replaced with the inner spec (VIEW wrapping element)
      assert.are.equal(LayoutSpec.Type.VIEW, result.children[1].type)
    end)

    it('should mount single child component via child property', function()
      local child_view = TestComponent({ name = 'child' })
      local spec = LayoutSpec.container(LayoutSpec.view(child_view, { id = 'c', flex = 1 }))
      mgr:parse_layout_spec(spec)
      assert.is_true(child_view._mounted)
    end)

    it('should handle nested layout specs recursively', function()
      local inner_child = TestComponent({ name = 'inner' })
      local outer_spec = LayoutSpec.horizontal({
        LayoutSpec.view(inner_child, { id = 'deep', flex = 1 }),
      })
      local OuterComponent = TestComponent:extend()
      function OuterComponent:constructor(props)
        local instance = OuterComponent.super.constructor(self, props)
        instance._outer_spec = outer_spec
        return instance
      end
      function OuterComponent:get_layout_spec()
        return self._outer_spec
      end
      local outer_child = OuterComponent({ name = 'outer' })
      local spec = LayoutSpec.container(LayoutSpec.view(outer_child, { id = 'outer', flex = 1 }))
      mgr:parse_layout_spec(spec)
      assert.is_true(outer_child._mounted)
      assert.is_true(inner_child._mounted)
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

  describe('render', function()
    it('should render a single TestComponent with real floating window', function()
      local root = TestComponent({ name = 'root' })
      mgr:render({
        component = root,
        mode = 'popup',
        width = 40,
        height = 20,
      })
      assert.is_true(root._mounted)
      assert.is_not_nil(root._element)
      assert.is_true(root._element:is_valid())
      assert.is_true(count_floating_windows() >= 1)
    end)

    it('should render nested children with real floating windows', function()
      local child = TestComponent({ name = 'child' })

      local WrapperComponent = TestComponent:extend()
      function WrapperComponent:get_layout_spec()
        return LayoutSpec.container(LayoutSpec.view(child, { flex = 1 }))
      end

      local wrapper = WrapperComponent({ name = 'wrapper' })
      mgr:render({
        component = wrapper,
        mode = 'popup',
        width = 40,
        height = 20,
      })
      assert.is_true(wrapper._mounted)
      assert.is_true(child._mounted)
    end)
  end)

  describe('destroy', function()
    it('should unmount all components and close windows', function()
      local root = TestComponent({ name = 'root' })
      mgr:render({
        component = root,
        mode = 'popup',
        width = 40,
        height = 20,
      })
      assert.is_true(root._mounted)
      assert.is_true(count_floating_windows() >= 1)

      mgr:destroy()
      assert.is_false(root._mounted)
      assert.are.equal(0, count_floating_windows())
    end)

    it('should be idempotent', function()
      local root = TestComponent({ name = 'root' })
      mgr:render({
        component = root,
        mode = 'popup',
        width = 40,
        height = 20,
      })
      mgr:destroy()
      assert.has_no.errors(function()
        mgr:destroy()
      end)
      assert.is_false(root._mounted)
    end)
  end)

  describe('render (screen mode)', function()
    local initial_tab_count

    before_each(function()
      initial_tab_count = vim.fn.tabpagenr('$')
    end)

    after_each(function()
      pcall(function() mgr:destroy() end)
      while vim.fn.tabpagenr('$') > initial_tab_count do
        vim.cmd('tabclose!')
      end
    end)

    it('should open a new tab', function()
      mgr:render({ component = TestComponent(), mode = 'screen' })
      assert.are.equal(initial_tab_count + 1, vim.fn.tabpagenr('$'))
    end)

    it('should close the new tab on destroy', function()
      mgr:render({ component = TestComponent(), mode = 'screen' })
      mgr:destroy()
      assert.are.equal(initial_tab_count, vim.fn.tabpagenr('$'))
    end)

    it('should preserve the original window after destroy', function()
      local original_win = vim.api.nvim_get_current_win()
      mgr:render({ component = TestComponent(), mode = 'screen' })
      mgr:destroy()
      assert.is_true(vim.api.nvim_win_is_valid(original_win))
    end)

    it('should not leave orphaned scratch buffers after render', function()
      local buf_count_before = #vim.api.nvim_list_bufs()
      mgr:render({ component = TestComponent(), mode = 'screen' })
      -- tabnew creates a scratch buffer; it should be deleted once VGit
      -- sets its own buffer into the window, leaving only the component buffer
      assert.are.equal(buf_count_before + 1, #vim.api.nvim_list_bufs())
      mgr:destroy()
    end)
  end)
end)
