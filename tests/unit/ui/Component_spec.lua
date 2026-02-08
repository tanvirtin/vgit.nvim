local Component = require('vgit.ui.Component')

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

describe('Component', function()
  local component

  before_each(function()
    component = TestComponent({})
  end)

  describe('constructor', function()
    it('should set initial props from argument', function()
      local c = TestComponent({ foo = 'bar' })
      assert.are.same({ foo = 'bar' }, c.props)
    end)

    it('should default props to empty table when nil', function()
      local c = TestComponent()
      assert.are.same({}, c.props)
    end)

    it('should set initial state from get_initial_state', function()
      assert.are.same({ count = 0 }, component.state)
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
      assert.are.same({ 'will_mount' }, component._log)
    end)

    it('should be idempotent - second mount is a no-op', function()
      component:mount()
      component._log = {}
      component:mount()
      assert.are.same({}, component._log)
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
      assert.are.same({ 'will_unmount' }, component._log)
    end)

    it('should reset _needs_update', function()
      component:mount()
      component._needs_update = true
      component:unmount()
      assert.is_false(component._needs_update)
    end)

    it('should be idempotent - unmount when not mounted is a no-op', function()
      component:unmount()
      assert.are.same({}, component._log)
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
      assert.are.same({ 'will_update', 'render', 'did_update' }, component._log)
    end)

    it('should not trigger update cycle when not mounted', function()
      component:set_props({ color = 'red' })
      assert.are.same({}, component._log)
      assert.are.equal('red', component.props.color)
    end)

    it('should be a no-op when updates is nil', function()
      component:mount()
      component._log = {}
      component:set_props(nil)
      assert.are.same({}, component._log)
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
      assert.are.same({ count = 0 }, component._prev_state_from_hook)
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
      assert.are.same({ 'will_update', 'render', 'did_update' }, component._log)
    end)

    it('should not trigger update cycle when not mounted', function()
      component:set_state({ count = 1 })
      assert.are.same({}, component._log)
      assert.are.equal(1, component.state.count)
    end)

    it('should be a no-op when updates is nil', function()
      component:mount()
      component._log = {}
      component:set_state(nil)
      assert.are.same({}, component._log)
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
      assert.are.same({ count = 0 }, component._prev_state_from_hook)
    end)
  end)

  describe('should_component_update gate', function()
    it('should skip update when should_component_update returns false (set_props)', function()
      local c = GatedComponent({})
      c:mount()
      c._log = {}
      c._allow_update = false
      c:set_props({ x = 1 })
      assert.are.same({}, c._log)
    end)

    it('should skip update when should_component_update returns false (set_state)', function()
      local c = GatedComponent({})
      c:mount()
      c._log = {}
      c._allow_update = false
      c:set_state({ count = 99 })
      assert.are.same({}, c._log)
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
      assert.are.same({}, component._log)
    end)

    it('should not run when _needs_update is false', function()
      component:mount()
      component._log = {}
      component._needs_update = false
      component:update(component.state)
      assert.are.same({}, component._log)
    end)

    it('should call will_update -> render -> did_update in order', function()
      component:mount()
      component._log = {}
      component._needs_update = true
      component:update({ count = 0 })
      assert.are.same({ 'will_update', 'render', 'did_update' }, component._log)
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

  describe('lifecycle ordering', function()
    it('should follow mount -> will_mount sequence', function()
      component:mount()
      assert.are.same({ 'will_mount' }, component._log)
      assert.is_true(component.mounted)
    end)

    it('should follow full mount -> set_props cycle', function()
      component:mount()
      component:set_props({ x = 1 })
      assert.are.same({
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
      assert.are.same({
        'will_mount',
        'will_update',
        'render',
        'did_update',
        'will_unmount',
      }, component._log)
    end)
  end)
end)
