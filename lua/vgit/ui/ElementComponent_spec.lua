local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('ElementComponent:', function()
  local ElementComponent
  local Editable

  before_each(function()
    ElementComponent = require('vgit.ui.ElementComponent')
    Editable = ElementComponent:extend()

    function Editable:get_buf_options()
      return { modifiable = true }
    end
  end)

  after_each(ui_helper.cleanup_ui)

  local function mounted(component)
    ui_helper.mount({ component = component, mode = 'popup', width = 40, height = 20 })

    return component
  end

  describe('before it is mounted', function()
    it('has no element, and answers harmlessly', function()
      local instance = ElementComponent({})

      assert.is_nil(instance._element)
      eq(false, instance:is_valid())
      eq(false, instance:is_focused())
      assert.is_nil(instance:get_lines())
      assert.is_nil(instance:with_element(function()
        return true
      end))
      assert.is_function(instance:on_click(1))
    end)

    it('returns itself from the calls that chain', function()
      local instance = ElementComponent({})

      eq(instance, instance:set_lines({ 'test' }))
    end)
  end)

  describe('mounting', function()
    it('creates its element, and not a second one on a second mount', function()
      local instance = ElementComponent({})

      instance:mount()

      local first = instance._element

      instance:mount()

      assert.is_not_nil(first)
      eq(first, instance._element)
    end)

    it('builds the element from the hooks a subclass overrides', function()
      local Subclass = ElementComponent:extend()

      function Subclass:get_buf_options()
        return { modifiable = true }
      end

      function Subclass:get_win_options()
        return { cursorline = false }
      end

      function Subclass:get_win_plot()
        return { focusable = false }
      end

      local instance = mounted(Subclass({}))

      eq(true, instance:is_valid())
      eq(true, instance._element:get_buffer():get_option('modifiable'))
    end)

    it('reads its options from the props when the subclass asks', function()
      local Subclass = ElementComponent:extend()

      function Subclass:get_win_options()
        return { winhl = self.props.winhl or 'Normal:Default', cursorline = false }
      end

      eq(true, mounted(Subclass({ winhl = 'Normal:Custom' })):is_valid())
    end)

    it('lets props override the hooks, and set the filetype', function()
      local Subclass = ElementComponent:extend()

      function Subclass:get_buf_options()
        return { filetype = 'text' }
      end

      local instance = mounted(Subclass({ filetype = 'lua', buf_options = { modifiable = true } }))
      local buffer = instance._element:get_buffer()

      eq('lua', buffer:get_option('filetype'))
      eq(true, buffer:get_option('modifiable'))
    end)

    it('merges the window options of its props over its own', function()
      local Subclass = ElementComponent:extend()

      function Subclass:get_win_options()
        return { cursorline = true, wrap = false }
      end

      eq(true, mounted(Subclass({ win_options = { cursorline = false } })):is_valid())
    end)
  end)

  describe('lifecycle', function()
    it('calls on_mount once the element exists', function()
      local Subclass = ElementComponent:extend()
      local seen

      function Subclass:on_mount()
        seen = self._element and self._element:is_valid()
      end

      mounted(Subclass({}))

      eq(true, seen)
    end)

    it('calls on_props with the props it had, only while mounted and only for real updates', function()
      local Subclass = ElementComponent:extend()
      local calls = {}

      function Subclass:on_props(prev)
        calls[#calls + 1] = prev.x
      end

      local instance = Subclass({ x = 1 })

      instance:set_props({ x = 2 })
      eq({}, calls)
      eq(2, instance.props.x)

      mounted(instance)
      instance:set_props({ x = 3 })
      instance:set_props(nil)

      eq({ 2 }, calls)
      eq(3, instance.props.x)
    end)

    it('merges props, and calls the callback it is given', function()
      local instance = mounted(ElementComponent({ a = 1, b = 2 }))
      local called = false

      instance:set_props({ b = 3, c = 4 }, function()
        called = true
      end)

      eq({ 1, 3, 4 }, { instance.props.a, instance.props.b, instance.props.c })
      eq(true, called)
    end)

    it('calls on_unmount before it lets go of the element, and only once', function()
      local Subclass = ElementComponent:extend()
      local valid, count = nil, 0

      function Subclass:on_unmount()
        valid = self._element and self._element:is_valid()
        count = count + 1
      end

      local instance = mounted(Subclass({}))

      instance:unmount()
      instance:unmount()

      eq({ true, 1 }, { valid, count })
      assert.is_nil(instance._element)
      eq(false, instance:is_mounted())
    end)
  end)

  describe('forwarding to its element', function()
    it('sets and reads lines, and returns itself so calls chain', function()
      local instance = mounted(Editable({}))

      eq(instance, instance:set_lines({ 'hello', 'world' }))
      eq({ 'hello', 'world' }, instance:get_lines())
      eq(2, instance:get_line_count())
      eq(instance, instance:clear_lines())
      eq(1, instance:get_line_count())
    end)

    it('moves and reads the cursor', function()
      local instance = mounted(Editable({}))

      instance:set_lines({ 'line1', 'line2', 'line3' })
      instance:set_cursor({ 2, 0 })

      eq(2, instance:get_cursor()[1])
    end)

    it('is valid once mounted', function()
      assert.is_truthy(mounted(Editable({})):is_valid())
    end)

    it('lets a subclass override a forwarder', function()
      local Subclass = Editable:extend()

      function Subclass:get_lines()
        return { 'custom' }
      end

      local instance = mounted(Subclass({}))

      instance:set_lines({ 'actual' })

      eq({ 'custom' }, instance:get_lines())
    end)

    it('hands its element to with_element', function()
      local instance = mounted(Editable({}))

      eq(
        true,
        instance:with_element(function(el)
          return el:is_valid()
        end)
      )
    end)
  end)

  describe('layout', function()
    it('is a view of its element with the options its subclass asks for', function()
      local Subclass = ElementComponent:extend()

      function Subclass:get_layout_opts()
        return { height = 3 }
      end

      local instance = mounted(Subclass({}))
      local spec = instance:get_layout_spec()

      eq({ 'view', 3, instance._element }, { spec.type, spec.height, spec.view })
    end)

    it('defaults to flex = 1', function()
      eq(1, mounted(ElementComponent({})):get_layout_spec().flex)
    end)
  end)

  describe('render', function()
    it('does nothing by default, and is triggered by set_state once mounted', function()
      local Subclass = ElementComponent:extend()
      local count = 0

      function Subclass:render()
        count = count + 1
      end

      local instance = Subclass({})

      instance:set_state({ x = 1 })
      eq(0, count)

      mounted(instance)

      local before = count

      instance:set_state({ x = 2 })

      assert.is_true(count > before)
      eq(2, instance.state.x)
    end)

    it('can draw into its element from on_mount', function()
      local Subclass = Editable:extend()

      function Subclass:on_mount()
        self:render()
      end

      function Subclass:render()
        self:set_lines({ 'rendered' })
      end

      eq({ 'rendered' }, mounted(Subclass({})):get_lines())
    end)
  end)

  describe('with a View', function()
    it('is mounted and unmounted with it', function()
      local Subclass = ElementComponent:extend()
      local events = {}

      function Subclass:on_mount()
        events[#events + 1] = 'mount'
      end

      function Subclass:on_unmount()
        events[#events + 1] = 'unmount'
      end

      local view = ui_helper.mount({ component = Subclass({}), mode = 'popup', width = 40, height = 20 })

      view:destroy()

      eq({ 'mount', 'unmount' }, events)
    end)
  end)
end)
