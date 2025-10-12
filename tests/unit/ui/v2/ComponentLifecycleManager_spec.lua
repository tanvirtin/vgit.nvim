local spy = require('luassert.spy')
local Component = require('vgit.ui.Component')
local ComponentLifecycleManager = require('vgit.ui.ComponentLifecycleManager')

describe('ComponentLifecycleManager', function()
  local manager
  local TestComponent
  local component
  local renderer

  before_each(function()
    manager = ComponentLifecycleManager()

    -- Create test component
    TestComponent = Component:extend()
    function TestComponent:render()
      return { type = 'view' }
    end

    component = TestComponent({ test_prop = 'value' })

    -- Mock renderer with context
    renderer = {
      context = {
        mode = 'popup',
        zindex = 2,
        get_props_for_component = function(self)
          return {
            mode = self.mode,
            dimensions = { width = 100, height = 50 },
            zindex = self.zindex,
          }
        end,
      },
    }
  end)

  describe('constructor', function()
    it('should initialize with empty mounted components', function()
      assert.are.same({}, manager.mounted_components)
    end)
  end)

  describe('mount', function()
    it('should mount component', function()
      local mount_spy = spy.on(component, 'mount')

      manager:mount(component, renderer)

      assert.spy(mount_spy).was.called(1)
    end)

    it('should add component to mounted list', function()
      manager:mount(component, renderer)

      assert.are.same(1, #manager.mounted_components)
      assert.are.same(component, manager.mounted_components[1])
    end)

    it('should inject context props before mounting', function()
      component.props = { existing_prop = 'value' }

      manager:mount(component, renderer)

      -- Should have both existing and injected props
      assert.are.same('value', component.props.existing_prop)
      assert.are.same('popup', component.props.mode)
      assert.are.same(2, component.props.zindex)
      assert.is_not_nil(component.props.dimensions)
    end)

    it('should not override existing props', function()
      component.props = { mode = 'custom', test = 'value' }

      manager:mount(component, renderer)

      -- Existing props should not be overridden
      assert.are.same('custom', component.props.mode)
      assert.are.same('value', component.props.test)
    end)

    it('should not mount already mounted component', function()
      component.mounted = true
      local mount_spy = spy.on(component, 'mount')

      manager:mount(component, renderer)

      assert.spy(mount_spy).was_not.called()
      assert.are.same(0, #manager.mounted_components)
    end)

    it('should handle renderer without context', function()
      local simple_renderer = {}

      assert.has_no.errors(function()
        manager:mount(component, simple_renderer)
      end)
    end)
  end)

  describe('call_did_mount', function()
    it('should call component_did_mount on all mounted components', function()
      local component1 = TestComponent()
      local component2 = TestComponent()

      component1.component_did_mount = spy.new(function() end)
      component2.component_did_mount = spy.new(function() end)

      manager:mount(component1, renderer)
      manager:mount(component2, renderer)

      manager:call_did_mount()

      -- Wait for vim.schedule
      vim.wait(10)

      assert.spy(component1.component_did_mount).was.called(1)
      assert.spy(component2.component_did_mount).was.called(1)
    end)

    it('should handle components without component_did_mount', function()
      local component1 = TestComponent()
      local component2 = TestComponent()
      component2.component_did_mount = spy.new(function() end)

      manager:mount(component1, renderer)
      manager:mount(component2, renderer)

      assert.has_no.errors(function()
        manager:call_did_mount()
        vim.wait(10)
      end)

      assert.spy(component2.component_did_mount).was.called(1)
    end)

    it('should call component_did_mount immediately', function()
      local component1 = TestComponent()
      component1.component_did_mount = spy.new(function() end)

      manager:mount(component1, renderer)
      manager:call_did_mount()

      assert.spy(component1.component_did_mount).was.called(1)
    end)
  end)

  describe('unmount_all', function()
    it('should unmount all components', function()
      local component1 = TestComponent()
      local component2 = TestComponent()

      local unmount_spy1 = spy.on(component1, 'unmount')
      local unmount_spy2 = spy.on(component2, 'unmount')

      manager:mount(component1, renderer)
      manager:mount(component2, renderer)
      manager:unmount_all()

      assert.spy(unmount_spy1).was.called(1)
      assert.spy(unmount_spy2).was.called(1)
    end)

    it('should clear mounted components list', function()
      local component1 = TestComponent()
      local component2 = TestComponent()

      manager:mount(component1, renderer)
      manager:mount(component2, renderer)

      assert.are.same(2, #manager.mounted_components)

      manager:unmount_all()

      assert.are.same(0, #manager.mounted_components)
    end)

    it('should handle components without unmount method', function()
      local component1 = { mounted = false }
      manager.mounted_components = { component1 }

      assert.has_no.errors(function()
        manager:unmount_all()
      end)

      assert.are.same(0, #manager.mounted_components)
    end)
  end)

  describe('get_mounted_components', function()
    it('should return empty array initially', function()
      local components = manager:get_mounted_components()
      assert.are.same({}, components)
    end)

    it('should return all mounted components', function()
      local component1 = TestComponent()
      local component2 = TestComponent()

      manager:mount(component1, renderer)
      manager:mount(component2, renderer)

      local components = manager:get_mounted_components()

      assert.are.same(2, #components)
      assert.are.same(component1, components[1])
      assert.are.same(component2, components[2])
    end)
  end)

  describe('is_mounted', function()
    it('should return false for unmounted component', function()
      assert.is_false(manager:is_mounted(component))
    end)

    it('should return true for mounted component', function()
      manager:mount(component, renderer)
      assert.is_true(manager:is_mounted(component))
    end)

    it('should return false after unmount_all', function()
      manager:mount(component, renderer)
      manager:unmount_all()

      assert.is_false(manager:is_mounted(component))
    end)
  end)

  describe('integration', function()
    it('should handle full lifecycle', function()
      local component1 = TestComponent()
      local component2 = TestComponent()

      component1.component_did_mount = spy.new(function() end)
      component2.component_did_mount = spy.new(function() end)

      -- Mount
      manager:mount(component1, renderer)
      manager:mount(component2, renderer)

      assert.is_true(manager:is_mounted(component1))
      assert.is_true(manager:is_mounted(component2))

      -- Call did mount
      manager:call_did_mount()
      vim.wait(10)

      assert.spy(component1.component_did_mount).was.called(1)
      assert.spy(component2.component_did_mount).was.called(1)

      -- Unmount
      manager:unmount_all()

      assert.is_false(manager:is_mounted(component1))
      assert.is_false(manager:is_mounted(component2))
    end)
  end)
end)
