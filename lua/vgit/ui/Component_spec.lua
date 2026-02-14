local Component = require('vgit.ui.Component')

local eq = assert.are.same

-- TestComponent that tracks lifecycle calls via a log table
local TestComponent = Component:extend()

function TestComponent:constructor(props)
  local instance = TestComponent.super.constructor(self, props)
  instance._log = {}
  return instance
end

function TestComponent:get_initial_state()
  return { count = 0 }
end

function TestComponent:component_will_mount()
  table.insert(self._log, 'will_mount')
end

function TestComponent:component_did_mount()
  table.insert(self._log, 'did_mount')
end

function TestComponent:component_will_update(next_state)
  table.insert(self._log, 'will_update')
end

function TestComponent:component_did_update(prev_state)
  table.insert(self._log, 'did_update')
  self._prev_state_from_hook = prev_state
end

function TestComponent:component_will_unmount()
  table.insert(self._log, 'will_unmount')
end

function TestComponent:render()
  table.insert(self._log, 'render')
end

-- GatedComponent that can block updates via should_component_update
local GatedComponent = TestComponent:extend()

function GatedComponent:constructor(props)
  local instance = GatedComponent.super.constructor(self, props)
  instance._allow_update = true
  return instance
end

function GatedComponent:should_component_update(next_props, next_state)
  return self._allow_update
end

describe('Component:', function()
  local component

  before_each(function()
    component = TestComponent({})
  end)

  describe('constructor', function()
    it('should set initial props from argument', function()
      local c = TestComponent({ foo = 'bar' })
      eq({ foo = 'bar' }, c.props)
    end)

    it('should default props to empty table when nil', function()
      local c = TestComponent()
      eq({}, c.props)
    end)

    it('should set initial state from get_initial_state', function()
      eq({ count = 0 }, component.state)
    end)

    it('should start unmounted', function()
      assert.is_false(component.mounted)
    end)

    it('should initialize _needs_update to false', function()
      assert.is_false(component._needs_update)
    end)
  end)

  describe('mount', function()
    it('should set mounted to true', function()
      component:mount()
      assert.is_true(component.mounted)
    end)

    it('should call component_will_mount before setting mounted', function()
      component:mount()
      eq({ 'will_mount' }, component._log)
    end)

    it('should be idempotent - second mount is a no-op', function()
      component:mount()
      component._log = {}
      component:mount()
      eq({}, component._log)
      assert.is_true(component.mounted)
    end)
  end)

  describe('unmount', function()
    it('should set mounted to false', function()
      component:mount()
      component:unmount()
      assert.is_false(component.mounted)
    end)

    it('should call component_will_unmount', function()
      component:mount()
      component._log = {}
      component:unmount()
      eq({ 'will_unmount' }, component._log)
    end)

    it('should reset _needs_update', function()
      component:mount()
      component._needs_update = true
      component:unmount()
      assert.is_false(component._needs_update)
    end)

    it('should be idempotent - unmount when not mounted is a no-op', function()
      component:unmount()
      eq({}, component._log)
      assert.is_false(component.mounted)
    end)
  end)

  describe('is_mounted', function()
    it('should return false before mount', function()
      assert.is_false(component:is_mounted())
    end)

    it('should return true after mount', function()
      component:mount()
      assert.is_true(component:is_mounted())
    end)

    it('should return false after unmount', function()
      component:mount()
      component:unmount()
      assert.is_false(component:is_mounted())
    end)
  end)

  describe('set_props', function()
    it('should merge updates into props', function()
      component:mount()
      component:set_props({ color = 'red' })
      assert.are.equal('red', component.props.color)
    end)

    it('should trigger update cycle when mounted', function()
      component:mount()
      component._log = {}
      component:set_props({ color = 'red' })
      eq({ 'will_update', 'render', 'did_update' }, component._log)
    end)

    it('should not trigger update cycle when not mounted', function()
      component:set_props({ color = 'red' })
      eq({}, component._log)
      assert.are.equal('red', component.props.color)
    end)

    it('should be a no-op when updates is nil', function()
      component:mount()
      component._log = {}
      component:set_props(nil)
      eq({}, component._log)
    end)

    it('should call callback after update', function()
      component:mount()
      local called = false
      component:set_props({ x = 1 }, function() called = true end)
      assert.is_true(called)
    end)

    it('should call callback even when not mounted', function()
      local called = false
      component:set_props({ x = 1 }, function() called = true end)
      assert.is_true(called)
    end)

    it('should pass prev_state to component_did_update', function()
      component:mount()
      component._log = {}
      component:set_props({ x = 1 })
      eq({ count = 0 }, component._prev_state_from_hook)
    end)
  end)

  describe('set_state', function()
    it('should merge updates into state', function()
      component:mount()
      component:set_state({ count = 5 })
      assert.are.equal(5, component.state.count)
    end)

    it('should trigger update cycle when mounted', function()
      component:mount()
      component._log = {}
      component:set_state({ count = 1 })
      eq({ 'will_update', 'render', 'did_update' }, component._log)
    end)

    it('should not trigger update cycle when not mounted', function()
      component:set_state({ count = 1 })
      eq({}, component._log)
      assert.are.equal(1, component.state.count)
    end)

    it('should be a no-op when updates is nil', function()
      component:mount()
      component._log = {}
      component:set_state(nil)
      eq({}, component._log)
    end)

    it('should call callback after update', function()
      component:mount()
      local called = false
      component:set_state({ count = 2 }, function() called = true end)
      assert.is_true(called)
    end)

    it('should pass prev_state to component_did_update', function()
      component:mount()
      component._log = {}
      component:set_state({ count = 42 })
      eq({ count = 0 }, component._prev_state_from_hook)
    end)
  end)

  describe('should_component_update gate', function()
    it('should skip update when should_component_update returns false (set_props)', function()
      local c = GatedComponent({})
      c:mount()
      c._log = {}
      c._allow_update = false
      c:set_props({ x = 1 })
      eq({}, c._log)
    end)

    it('should skip update when should_component_update returns false (set_state)', function()
      local c = GatedComponent({})
      c:mount()
      c._log = {}
      c._allow_update = false
      c:set_state({ count = 99 })
      eq({}, c._log)
      -- State should not be updated when gate returns false
      assert.are.equal(0, c.state.count)
    end)

    it('should not call callback when should_component_update returns false', function()
      local c = GatedComponent({})
      c:mount()
      c._allow_update = false
      local called = false
      c:set_props({ x = 1 }, function() called = true end)
      assert.is_false(called)
    end)
  end)

  describe('update', function()
    it('should not run when not mounted', function()
      component._needs_update = true
      component:update(component.state)
      eq({}, component._log)
    end)

    it('should not run when _needs_update is false', function()
      component:mount()
      component._log = {}
      component._needs_update = false
      component:update(component.state)
      eq({}, component._log)
    end)

    it('should call will_update -> render -> did_update in order', function()
      component:mount()
      component._log = {}
      component._needs_update = true
      component:update({ count = 0 })
      eq({ 'will_update', 'render', 'did_update' }, component._log)
    end)

    it('should reset _needs_update after update', function()
      component:mount()
      component._needs_update = true
      component:update(component.state)
      assert.is_false(component._needs_update)
    end)
  end)

  describe('on and set_keymap guards', function()
    it('should not error when _element is nil (on)', function()
      assert.has_no.errors(function()
        component:on('BufEnter', function() end)
      end)
    end)

    it('should not error when _element is nil (set_keymap)', function()
      assert.has_no.errors(function()
        component:set_keymap('n', 'q', function() end, 'quit')
      end)
    end)

    it('should delegate to _element.on when _element exists', function()
      local called_with = {}
      component._element = {
        on = function(_, event, cb)
          called_with.event = event
          called_with.cb = cb
        end,
      }
      local fn = function() end
      component:on('BufEnter', fn)
      assert.are.equal('BufEnter', called_with.event)
      assert.are.equal(fn, called_with.cb)
    end)

    it('should delegate to _element.set_keymap when _element exists', function()
      local called_with = {}
      component._element = {
        set_keymap = function(_, mode, key, handler, desc)
          called_with = { mode = mode, key = key, handler = handler, desc = desc }
        end,
      }
      local fn = function() end
      component:set_keymap('n', 'q', fn, 'quit')
      assert.are.equal('n', called_with.mode)
      assert.are.equal('q', called_with.key)
      assert.are.equal(fn, called_with.handler)
      assert.are.equal('quit', called_with.desc)
    end)
  end)

  describe('with_element', function()
    it('should return nil when _element is nil', function()
      local called = false
      local result = component:with_element(function() called = true; return 42 end)
      assert.is_false(called)
      assert.is_nil(result)
    end)

    it('should return nil when _element is_valid returns false', function()
      component._element = { is_valid = function() return false end }
      local called = false
      local result = component:with_element(function() called = true; return 42 end)
      assert.is_false(called)
      assert.is_nil(result)
    end)

    it('should call fn with element when valid', function()
      local mock_element = { is_valid = function() return true end }
      component._element = mock_element
      local received_element
      component:with_element(function(el)
        received_element = el
      end)
      assert.are.equal(mock_element, received_element)
    end)

    it('should forward return value', function()
      component._element = { is_valid = function() return true end }
      local result = component:with_element(function() return 'hello' end)
      assert.are.equal('hello', result)
    end)
  end)

  describe('forward', function()
    it('should create delegating methods on a class', function()
      local MyComponent = Component:extend()
      local target = {
        get_value = function(self) return 42 end,
      }
      Component.forward(MyComponent, function(self) return target end, { 'get_value' })
      local instance = MyComponent()
      assert.are.equal(42, instance:get_value())
    end)

    it('should return nil when target is nil', function()
      local MyComponent = Component:extend()
      Component.forward(MyComponent, function(self) return nil end, { 'get_value' })
      local instance = MyComponent()
      assert.is_nil(instance:get_value())
    end)

    it('should forward multiple methods', function()
      local MyComponent = Component:extend()
      local target = {
        get_a = function(self) return 'a' end,
        get_b = function(self) return 'b' end,
      }
      Component.forward(MyComponent, function(self) return target end, { 'get_a', 'get_b' })
      local instance = MyComponent()
      assert.are.equal('a', instance:get_a())
      assert.are.equal('b', instance:get_b())
    end)

    it('should pass arguments to target method', function()
      local MyComponent = Component:extend()
      local target = {
        add = function(self, a, b) return a + b end,
      }
      Component.forward(MyComponent, function(self) return target end, { 'add' })
      local instance = MyComponent()
      assert.are.equal(5, instance:add(2, 3))
    end)

    it('should be overrideable by explicit method', function()
      local MyComponent = Component:extend()
      local target = {
        get_value = function(self) return 'from_target' end,
      }
      Component.forward(MyComponent, function(self) return target end, { 'get_value' })
      function MyComponent:get_value() return 'overridden' end
      local instance = MyComponent()
      assert.are.equal('overridden', instance:get_value())
    end)
  end)

  describe('lifecycle ordering', function()
    it('should follow mount -> will_mount sequence', function()
      component:mount()
      eq({ 'will_mount' }, component._log)
      assert.is_true(component.mounted)
    end)

    it('should follow full mount -> set_props cycle', function()
      component:mount()
      component:set_props({ x = 1 })
      eq({
        'will_mount',
        'will_update',
        'render',
        'did_update',
      }, component._log)
    end)

    it('should follow mount -> set_state -> unmount cycle', function()
      component:mount()
      component:set_state({ count = 10 })
      component:unmount()
      eq({
        'will_mount',
        'will_update',
        'render',
        'did_update',
        'will_unmount',
      }, component._log)
    end)
  end)
end)
