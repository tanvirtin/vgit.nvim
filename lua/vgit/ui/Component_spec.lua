local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('Component:', function()
  local Component
  local ComponentManager

  before_each(function()
    Component = require('vgit.ui.Component')
    ComponentManager = require('vgit.ui.ComponentManager')
  end)

  after_each(ui_helper.cleanup_ui)

  local function mount_component(component)
    ComponentManager():render({ component = component, mode = 'popup', width = 40, height = 20 })
    return component
  end

  describe('factory', function()
    it('should return a callable class', function()
      local MyComponent = Component({})
      local instance = MyComponent({ x = 1 })

      assert.is_not_nil(instance)
      eq(1, instance.props.x)
    end)

    it('should return instances with default state', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      assert.is_table(instance.state)
    end)

    it('should set _mounted to false initially', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      assert.is_false(instance:is_mounted())
    end)

    it('should support get_initial_state defined on class', function()
      local MyComponent = Component({})

      function MyComponent:get_initial_state()
        return { count = 0, items = {} }
      end

      local instance = MyComponent({})

      eq(0, instance.state.count)
      eq({}, instance.state.items)
    end)
  end)

  describe('single-element', function()
    it('should create element during mount', function()
      local MyComponent = Component({
        win_options = { cursorline = false },
      })
      local instance = mount_component(MyComponent({}))

      assert.is_not_nil(instance._element)
      assert.is_truthy(instance._element:is_valid())
    end)

    it('should apply buf_options from config', function()
      local MyComponent = Component({
        buf_options = { modifiable = true, buflisted = false, bufhidden = 'wipe' },
      })
      local instance = mount_component(MyComponent({}))
      local buf = instance._element:get_buffer()

      assert.is_true(buf:get_option('modifiable'))
    end)

    it('should merge win_options from props', function()
      local MyComponent = Component({
        win_options = { cursorline = true, wrap = false },
      })
      local instance = mount_component(MyComponent({ win_options = { cursorline = false } }))

      assert.is_truthy(instance._element:is_valid())
    end)

    it('should apply filetype from props', function()
      local MyComponent = Component({
        buf_options = { filetype = 'text' },
      })
      local instance = mount_component(MyComponent({ filetype = 'lua' }))
      local buf = instance._element:get_buffer()

      eq('lua', buf:get_option('filetype'))
    end)

    it('should support function win_options', function()
      local MyComponent = Component({
        win_options = function(props)
          return { winhl = props.winhl or 'Normal:Default', cursorline = false }
        end,
      })
      local instance = mount_component(MyComponent({ winhl = 'Normal:Custom' }))

      assert.is_truthy(instance._element:is_valid())
    end)

    it('should apply win_plot from config', function()
      local MyComponent = Component({
        win_plot = { focusable = false },
      })
      local instance = mount_component(MyComponent({}))

      assert.is_truthy(instance._element:is_valid())
    end)

    it('should not recreate element on second mount', function()
      local MyComponent = Component({})
      local instance = MyComponent({})
      instance:mount()
      local first_element = instance._element
      instance:mount()

      eq(first_element, instance._element)
    end)
  end)

  describe('lifecycle', function()
    it('should call on_mount after windows exist', function()
      local mount_called = false
      local element_valid = false
      local MyComponent = Component({
        on_mount = function(self)
          mount_called = true
          element_valid = self._element and self._element:is_valid()
        end,
      })
      mount_component(MyComponent({}))

      assert.is_true(mount_called)
      assert.is_true(element_valid)
    end)

    it('should call on_props when set_props is called while mounted', function()
      local prev = nil
      local MyComponent = Component({
        on_props = function(self, prev_props)
          prev = prev_props
        end,
      })
      local instance = mount_component(MyComponent({ x = 1 }))
      instance:set_props({ x = 2 })

      assert.is_not_nil(prev)
      eq(1, prev.x)
      eq(2, instance.props.x)
    end)

    it('should not call on_props when not mounted', function()
      local called = false
      local MyComponent = Component({
        on_props = function() called = true end,
      })
      local instance = MyComponent({ x = 1 })
      instance:set_props({ x = 2 })

      assert.is_false(called)
      eq(2, instance.props.x)
    end)

    it('should not call on_props when updates is nil', function()
      local called = false
      local MyComponent = Component({
        on_props = function() called = true end,
      })
      local instance = mount_component(MyComponent({}))
      instance:set_props(nil)

      assert.is_false(called)
    end)

    it('should call on_unmount before element cleanup', function()
      local element_was_valid = false
      local MyComponent = Component({
        on_unmount = function(self)
          element_was_valid = self._element and self._element:is_valid()
        end,
      })
      local instance = mount_component(MyComponent({}))
      instance:unmount()

      assert.is_true(element_was_valid)
    end)

    it('should clean up element on unmount', function()
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({}))
      instance:unmount()

      assert.is_nil(instance._element)
      assert.is_false(instance:is_mounted())
    end)

    it('should be safe to unmount twice', function()
      local count = 0
      local MyComponent = Component({
        on_unmount = function() count = count + 1 end,
      })
      local instance = mount_component(MyComponent({}))
      instance:unmount()
      instance:unmount()

      eq(1, count)
    end)

    it('should call set_props callback', function()
      local called = false
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({}))
      instance:set_props({ x = 1 }, function() called = true end)

      assert.is_true(called)
    end)

    it('should merge props correctly', function()
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({ a = 1, b = 2 }))
      instance:set_props({ b = 3, c = 4 })

      eq(1, instance.props.a)
      eq(3, instance.props.b)
      eq(4, instance.props.c)
    end)
  end)

  describe('auto-delegation', function()
    it('should delegate set_lines to element', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })
      local instance = mount_component(MyComponent({}))
      instance:set_lines({ 'hello', 'world' })

      eq({ 'hello', 'world' }, instance:get_lines())
    end)

    it('should delegate set_cursor to element', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })
      local instance = mount_component(MyComponent({}))
      instance:set_lines({ 'line1', 'line2', 'line3' })
      instance:set_cursor({ 2, 0 })

      local cursor = instance:get_cursor()
      eq(2, cursor[1])
    end)

    it('should return component for chainable methods', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })
      local instance = mount_component(MyComponent({}))
      local result = instance:set_lines({ 'test' })

      eq(instance, result)
    end)

    it('should return nil when element is not valid', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      assert.is_nil(instance:set_lines({ 'test' }))
    end)

    it('should allow class methods to override delegation', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })

      function MyComponent:get_lines()
        return { 'custom' }
      end

      local instance = mount_component(MyComponent({}))
      instance:set_lines({ 'actual' })

      eq({ 'custom' }, instance:get_lines())
    end)

    it('should delegate is_valid', function()
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({}))

      assert.is_truthy(instance:is_valid())
    end)

    it('should delegate get_line_count', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })
      local instance = mount_component(MyComponent({}))
      instance:set_lines({ 'a', 'b', 'c' })

      eq(3, instance:get_line_count())
    end)
  end)

  describe('get_layout_spec', function()
    it('should return view spec with config layout_opts', function()
      local MyComponent = Component({
        layout_opts = { height = 3 },
      })
      local instance = mount_component(MyComponent({}))
      local spec = instance:get_layout_spec()

      eq('view', spec.type)
      eq(3, spec.height)
    end)

    it('should default to flex = 1', function()
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({}))
      local spec = instance:get_layout_spec()

      eq(1, spec.flex)
    end)

    it('should reference the element', function()
      local MyComponent = Component({})
      local instance = mount_component(MyComponent({}))
      local spec = instance:get_layout_spec()

      eq(instance._element, spec.view)
    end)
  end)

  describe('render', function()
    it('should be a no-op by default', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      assert.is_nil(instance:render())
    end)

    it('should call custom render on the class', function()
      local render_called = false
      local MyComponent = Component({})

      function MyComponent:render()
        render_called = true
      end

      local instance = MyComponent({})
      instance:render()

      assert.is_true(render_called)
    end)

    it('should be triggered by set_state when mounted', function()
      local render_count = 0
      local MyComponent = Component({})

      function MyComponent:render()
        render_count = render_count + 1
      end

      local instance = mount_component(MyComponent({}))
      local initial_count = render_count
      instance:set_state({ x = 1 })

      assert.is_true(render_count > initial_count)
      eq(1, instance.state.x)
    end)
  end)

  describe('viewport', function()
    it('should have viewport tracking methods when viewport = true', function()
      local MyComponent = Component({ viewport = true })
      local instance = MyComponent({})

      assert.is_function(instance.mark_viewport_dirty)
      assert.is_function(instance.is_viewport_unchanged)
      assert.is_function(instance.commit_viewport)
      assert.is_function(instance.ensure_renderer_attached)
    end)

    it('should initialize viewport state when viewport = true', function()
      local MyComponent = Component({ viewport = true })
      local instance = MyComponent({})

      assert.is_true(instance._viewport_dirty)
      assert.is_nil(instance._last_top)
      assert.is_nil(instance._last_bot)
      assert.is_false(instance._renderer_attached)
    end)

    it('should support viewport dirty tracking', function()
      local MyComponent = Component({ viewport = true })
      local instance = MyComponent({})

      assert.is_true(instance._viewport_dirty)
      instance:commit_viewport(1, 10)
      assert.is_false(instance._viewport_dirty)
      assert.is_true(instance:is_viewport_unchanged(1, 10))
      instance:mark_viewport_dirty()
      assert.is_false(instance:is_viewport_unchanged(1, 10))
    end)

    it('should not have viewport methods when viewport is not set', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      assert.is_nil(instance._viewport_dirty)
      assert.is_nil(rawget(getmetatable(instance), 'mark_viewport_dirty'))
    end)
  end)

  describe('multi-element', function()
    it('should create elements from config', function()
      local MyComponent = Component({
        elements = {
          input = { buf_options = { modifiable = true, buflisted = false, bufhidden = 'wipe' } },
          list = { buf_options = { modifiable = false, buflisted = false, bufhidden = 'wipe' } },
        },
      })
      local instance = MyComponent({})
      instance:mount()

      assert.is_not_nil(instance.elements.input)
      assert.is_not_nil(instance.elements.list)
    end)

    it('should call layout() for get_layout_spec', function()
      local MyComponent = Component({
        elements = {
          input = {},
          list = {},
        },
      })

      function MyComponent:layout(spec)
        return spec.vertical({
          spec.view(self.elements.input, { height = 1 }),
          spec.view(self.elements.list, { flex = 1 }),
        })
      end

      local instance = MyComponent({})
      instance:mount()
      local spec = instance:get_layout_spec()

      eq('flex', spec.type)
      eq(2, #spec.children)
    end)

    it('should clean up elements on unmount', function()
      local MyComponent = Component({
        elements = {
          input = { buf_options = { modifiable = true, buflisted = false, bufhidden = 'wipe' } },
          list = {},
        },
      })
      local instance = MyComponent({})
      instance:mount()
      instance._mounted = true
      instance:unmount()

      eq({}, instance.elements)
      assert.is_false(instance:is_mounted())
    end)

    it('should not have auto-delegated methods', function()
      local MyComponent = Component({
        elements = { a = {} },
      })
      local instance = MyComponent({})

      -- set_lines is NOT delegated for multi-element
      -- It inherits from ComponentBase which doesn't have set_lines
      assert.is_nil(rawget(MyComponent, 'set_lines'))
    end)
  end)

  describe('composite', function()
    it('should create child instances from classes', function()
      local ChildComponent = Component({})
      local ParentComponent = Component({
        children = {
          left = ChildComponent,
          right = ChildComponent,
        },
      })
      local instance = ParentComponent({})
      instance:mount()

      assert.is_not_nil(instance.children.left)
      assert.is_not_nil(instance.children.right)
    end)

    it('should create children with empty props', function()
      local ChildComponent = Component({})
      local ParentComponent = Component({
        children = { child = ChildComponent },
      })
      local instance = ParentComponent({})
      instance:mount()

      assert.is_table(instance.children.child.props)
    end)

    it('should not unmount children (ComponentManager handles that)', function()
      local ChildComponent = Component({})
      local ParentComponent = Component({
        children = { child = ChildComponent },
      })
      local instance = ParentComponent({})
      instance:mount()

      local child = instance.children.child
      child._mounted = true

      instance:unmount()

      assert.is_true(child._mounted)
    end)

    it('should call layout() for get_layout_spec', function()
      local ChildComponent = Component({})
      local ParentComponent = Component({
        children = {
          left = ChildComponent,
          right = ChildComponent,
        },
      })

      function ParentComponent:layout(spec)
        return spec.horizontal({
          spec.view(self.children.left, { flex = 1 }),
          spec.view(self.children.right, { flex = 1 }),
        })
      end

      local instance = ParentComponent({})
      instance:mount()
      local spec = instance:get_layout_spec()

      eq('flex', spec.type)
      eq(2, #spec.children)
    end)
  end)

  describe('with_element', function()
    it('should work with single-element components', function()
      local MyComponent = Component({
        buf_options = { modifiable = true },
      })
      local instance = mount_component(MyComponent({}))

      local result = instance:with_element(function(el)
        return el:is_valid()
      end)

      assert.is_true(result)
    end)

    it('should return nil when element is not valid', function()
      local MyComponent = Component({})
      local instance = MyComponent({})

      local result = instance:with_element(function()
        return true
      end)

      assert.is_nil(result)
    end)
  end)

  describe('ComponentManager compatibility', function()
    it('should work with ComponentManager render', function()
      local mounted = false
      local MyComponent = Component({
        on_mount = function() mounted = true end,
      })

      local cm = ComponentManager()
      cm:render({ component = MyComponent({}), mode = 'popup', width = 40, height = 20 })

      assert.is_true(mounted)
    end)

    it('should be destroyable via ComponentManager', function()
      local unmounted = false
      local MyComponent = Component({
        on_unmount = function() unmounted = true end,
      })

      local cm = ComponentManager()
      cm:render({ component = MyComponent({}), mode = 'popup', width = 40, height = 20 })
      cm:destroy()

      assert.is_true(unmounted)
    end)

    it('should work with custom render and on_mount', function()
      local lines_set = false
      local MyComponent = Component({
        buf_options = { modifiable = true },
        on_mount = function(self)
          self:render()
        end,
      })

      function MyComponent:render()
        self:with_element(function(el)
          el:set_lines({ 'rendered' })
          lines_set = true
        end)
      end

      mount_component(MyComponent({}))

      assert.is_true(lines_set)
    end)
  end)
end)
