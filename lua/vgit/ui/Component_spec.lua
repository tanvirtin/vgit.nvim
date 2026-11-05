local eq = assert.are.same

describe('Component:', function()
  local Component

  before_each(function()
    Component = require('vgit.ui.Component')
  end)

  it('keeps the props it is given, and has empty ones otherwise', function()
    eq({ x = 1 }, Component({ x = 1 }).props)
    eq({}, Component().props)
  end)

  it('starts with the state its subclass declares', function()
    local Subclass = Component:extend()

    function Subclass:get_initial_state()
      return { count = 0, items = {} }
    end

    local instance = Subclass({})

    eq(0, instance.state.count)
    eq({}, instance.state.items)
    eq({}, Component({}).state)
  end)

  it('is not mounted until it is, and mounts and unmounts as a flag', function()
    local instance = Component({})

    eq(false, instance:is_mounted())
    instance:mount()
    eq(true, instance:is_mounted())
    instance:unmount()
    eq(false, instance:is_mounted())
  end)

  it('has no element, so with_element gives nothing', function()
    assert.is_nil(Component({}):with_element(function()
      return true
    end))
  end)

  describe('set_props', function()
    it('merges the updates, drops vim.NIL, and calls the callback', function()
      local instance = Component({ a = 1, b = 2 })
      local called = false

      instance:set_props({ b = vim.NIL, c = 4 }, function()
        called = true
      end)

      eq({ a = 1, c = 4 }, instance.props)
      eq(true, called)
    end)

    it('does nothing for nil', function()
      local instance = Component({ a = 1 })

      instance:set_props(nil)

      eq({ a = 1 }, instance.props)
    end)

    it('tells on_props what the props were, only once the component is mounted', function()
      local Subclass = Component:extend()
      local seen = {}

      function Subclass:on_props(prev)
        seen[#seen + 1] = prev.x
      end

      local instance = Subclass({ x = 1 })

      instance:set_props({ x = 2 })
      instance:mount()
      instance:set_props({ x = 3 })

      eq({ 2 }, seen)
    end)
  end)

  describe('set_state', function()
    it('merges the updates, and renders only once mounted', function()
      local Subclass = Component:extend()
      local renders = 0

      function Subclass:render()
        renders = renders + 1
      end

      local instance = Subclass({})

      instance:set_state({ x = 1 })
      eq(0, renders)

      instance:mount()
      instance:set_state({ y = 2 })

      eq({ 1, 2, 1 }, { instance.state.x, instance.state.y, renders })
    end)

    it('does nothing for nil', function()
      local instance = Component({})

      instance:set_state(nil)

      eq({}, instance.state)
    end)
  end)

  it('does nothing in render, on_mount, on_props and on_unmount unless a subclass says otherwise', function()
    local instance = Component({})

    assert.is_nil(instance:render())
    assert.is_nil(instance:on_mount())
    assert.is_nil(instance:on_props({}))
    assert.is_nil(instance:on_unmount())
  end)

  it('is not a declaration: calling it makes an instance, as any class does', function()
    local instance = Component({ hooks = true })

    assert.is_true(instance:is(Component))
    eq(true, instance.props.hooks)
  end)
end)
