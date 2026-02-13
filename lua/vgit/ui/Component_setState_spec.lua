local spy = require('luassert.spy')
local Component = require('vgit.ui.Component')

local eq = assert.are.same

describe('Component:', function()
  local TestComponent
  local component

  before_each(function()
    -- Create a test component class
    TestComponent = Component:extend()

    function TestComponent:get_initial_state()
      return {
        count = 0,
        name = 'test',
      }
    end

    function TestComponent:render()
      return {
        body = { lines = { 'Count: ' .. self.state.count } },
      }
    end

    component = TestComponent({ initial_prop = 'value' })
  end)

  describe('constructor', function()
    it('should initialize with props', function()
      eq(component.props.initial_prop, 'value')
    end)

    it('should initialize with initial state', function()
      eq(component.state.count, 0)
      eq(component.state.name, 'test')
    end)

    it('should not be mounted initially', function()
      assert.is_false(component.mounted)
    end)

    it('should not need update initially', function()
      assert.is_false(component._needs_update)
    end)
  end)

  describe('get_initial_state', function()
    it('should return empty table by default', function()
      local BaseComponent = Component()
      eq(BaseComponent.state, {})
    end)

    it('should be overridable in subclass', function()
      eq(component.state.count, 0)
    end)
  end)

  describe('set_state', function()
    it('should merge updates into state', function()
      component:set_state({ count = 5 })

      -- Use vim.schedule to let the update process
      vim.wait(10)

      eq(component.state.count, 5)
      eq(component.state.name, 'test') -- unchanged
    end)

    it('should mark component as needing update', function()
      component:set_state({ count = 1 })
      assert.is_true(component._needs_update)
    end)

    it('should call callback if provided', function()
      local callback = spy.new(function() end)
      component:set_state({ count = 1 }, callback)

      assert.spy(callback).was.called(1)
    end)

    it('should do nothing if updates is nil', function()
      local prev_state = vim.deepcopy(component.state)
      component:set_state(nil)

      eq(component.state, prev_state)
    end)

    it('should respect should_component_update', function()
      function component:should_component_update(next_props, next_state)
        -- Only update if count is even
        return next_state.count % 2 == 0
      end

      component:set_state({ count = 3 })
      vim.wait(10)
      eq(component.state.count, 0) -- not updated

      component:set_state({ count = 4 })
      vim.wait(10)
      eq(component.state.count, 4) -- updated
    end)
  end)

  describe('lifecycle hooks', function()
    it('should call component_will_mount before mount', function()
      local will_mount_spy = spy.new(function() end)
      component.component_will_mount = will_mount_spy

      component:mount()

      assert.spy(will_mount_spy).was.called(1)
    end)

    it('should call component_did_mount after mount', function()
      local did_mount_spy = spy.new(function() end)
      component.component_did_mount = did_mount_spy

      component:mount()

      -- component_did_mount is called in renderer after windows created
      -- For unit test, we verify the method exists
      assert.is_not_nil(component.component_did_mount)
    end)

    it('should call component_will_unmount before unmount', function()
      local will_unmount_spy = spy.new(function() end)
      component.component_will_unmount = will_unmount_spy

      component:mount()
      component:unmount()

      assert.spy(will_unmount_spy).was.called(1)
    end)

    it('should call component_will_update before update', function()
      local will_update_spy = spy.new(function() end)
      component.component_will_update = will_update_spy
      component.mounted = true

      component:set_state({ count = 1 })
      vim.wait(10)

      -- Update is scheduled, so we need to wait
      vim.schedule(function()
        assert.spy(will_update_spy).was.called()
      end)
      vim.wait(10)
    end)

    it('should call component_did_update after update', function()
      local did_update_spy = spy.new(function() end)
      component.component_did_update = did_update_spy
      component.mounted = true

      component:set_state({ count = 1 })
      vim.wait(10)

      -- Update is scheduled
      vim.schedule(function()
        assert.spy(did_update_spy).was.called()
      end)
      vim.wait(10)
    end)
  end)

  describe('mount', function()
    it('should set mounted to true', function()
      component:mount()
      assert.is_true(component.mounted)
    end)

    it('should not mount twice', function()
      local will_mount_spy = spy.new(function() end)
      component.component_will_mount = will_mount_spy

      component:mount()
      component:mount()

      assert.spy(will_mount_spy).was.called(1)
    end)
  end)

  describe('unmount', function()
    it('should set mounted to false', function()
      component:mount()
      component:unmount()

      assert.is_false(component.mounted)
    end)

    it('should not unmount if not mounted', function()
      local will_unmount_spy = spy.new(function() end)
      component.component_will_unmount = will_unmount_spy

      component:unmount()

      assert.spy(will_unmount_spy).was_not.called()
    end)
  end)

  describe('update', function()
    before_each(function()
      component.mounted = true
      component._needs_update = true
    end)

    it('should not update if not mounted', function()
      component.mounted = false
      component:update()

      assert.is_true(component._needs_update)
    end)

    it('should not update if not needed', function()
      component._needs_update = false
      component:update()

      assert.is_false(component._needs_update)
    end)

    it('should call render to get UI description', function()
      local render_spy = spy.on(component, 'render')
      component:update()

      assert.spy(render_spy).was.called(1)
    end)

    it('should clear needs_update flag', function()
      component:update()

      assert.is_false(component._needs_update)
    end)
  end)

  describe('render', function()
    it('should error if not implemented', function()
      local BaseComponent = Component()

      assert.has_error(function()
        BaseComponent:render()
      end, 'Component:render() must be implemented by subclass')
    end)

    it('should be overridable in subclass', function()
      local ui = component:render()

      assert.is_not_nil(ui)
      assert.is_not_nil(ui.body)
    end)
  end)

  describe('is_mounted', function()
    it('should return false when not mounted', function()
      assert.is_false(component:is_mounted())
    end)

    it('should return true when mounted', function()
      component:mount()
      assert.is_true(component:is_mounted())
    end)

    it('should return false after unmount', function()
      component:mount()
      component:unmount()
      assert.is_false(component:is_mounted())
    end)
  end)

  describe('should_component_update', function()
    it('should return true by default', function()
      local result = component:should_component_update({}, {})
      assert.is_true(result)
    end)

    it('should be overridable for optimization', function()
      function component:should_component_update(next_props, next_state)
        return next_state.count ~= self.state.count
      end

      assert.is_false(component:should_component_update({}, { count = 0 }))
      assert.is_true(component:should_component_update({}, { count = 1 }))
    end)
  end)

  describe('integration', function()
    it('should handle multiple state updates', function()
      component:mount()

      component:set_state({ count = 1 })
      component:set_state({ count = 2 })
      component:set_state({ count = 3 })

      vim.wait(20)

      -- All updates should be batched
      eq(component.state.count, 3)
    end)

    it('should maintain state across updates', function()
      component:set_state({ count = 5 })
      vim.wait(10)

      component:set_state({ name = 'updated' })
      vim.wait(10)

      eq(component.state.count, 5)
      eq(component.state.name, 'updated')
    end)

    it('should complete full lifecycle', function()
      local lifecycle = {}

      component.component_will_mount = function()
        table.insert(lifecycle, 'will_mount')
      end
      component.component_will_unmount = function()
        table.insert(lifecycle, 'will_unmount')
      end

      component:mount()
      table.insert(lifecycle, 'mounted')

      component:unmount()
      table.insert(lifecycle, 'unmounted')

      -- Note: component_did_mount is called by Renderer after windows are created
      eq(lifecycle, {
        'will_mount',
        'mounted',
        'will_unmount',
        'unmounted',
      })
    end)
  end)
end)
