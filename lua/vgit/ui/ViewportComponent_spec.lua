local ViewportComponent = require('vgit.ui.ViewportComponent')
local Component = require('vgit.ui.Component')

local eq = assert.are.same

local TestViewportComponent = ViewportComponent:extend()

function TestViewportComponent:constructor(props)
  local instance = TestViewportComponent.super.constructor(self, props)
  instance._log = {}
  return instance
end

function TestViewportComponent:render()
  table.insert(self._log, 'render')
end

describe('ViewportComponent:', function()
  local component

  before_each(function()
    component = TestViewportComponent({})
  end)

  describe('constructor', function()
    it('should inherit Component fields', function()
      eq({}, component.props)
      assert.is_false(component.mounted)
      assert.is_false(component._needs_update)
    end)

    it('should initialize viewport fields', function()
      assert.is_true(component._viewport_dirty)
      assert.is_nil(component._last_top)
      assert.is_nil(component._last_bot)
      assert.is_false(component._renderer_attached)
    end)
  end)

  describe('mark_viewport_dirty', function()
    it('should set _viewport_dirty to true', function()
      component._viewport_dirty = false
      component:mark_viewport_dirty()
      assert.is_true(component._viewport_dirty)
    end)
  end)

  describe('is_viewport_unchanged', function()
    it('should return false when viewport is dirty', function()
      component._viewport_dirty = true
      component._last_top = 1
      component._last_bot = 10
      assert.is_false(component:is_viewport_unchanged(1, 10))
    end)

    it('should return false when top changed', function()
      component._viewport_dirty = false
      component._last_top = 1
      component._last_bot = 10
      assert.is_false(component:is_viewport_unchanged(2, 10))
    end)

    it('should return false when bot changed', function()
      component._viewport_dirty = false
      component._last_top = 1
      component._last_bot = 10
      assert.is_false(component:is_viewport_unchanged(1, 20))
    end)

    it('should return true when viewport is clean and range unchanged', function()
      component._viewport_dirty = false
      component._last_top = 1
      component._last_bot = 10
      assert.is_true(component:is_viewport_unchanged(1, 10))
    end)
  end)

  describe('commit_viewport', function()
    it('should store top and bot and clear dirty flag', function()
      component._viewport_dirty = true
      component:commit_viewport(5, 15)
      assert.is_false(component._viewport_dirty)
      eq(5, component._last_top)
      eq(15, component._last_bot)
    end)
  end)

  describe('ensure_renderer_attached', function()
    it('should call attach_fn on first call', function()
      local called = false
      component:ensure_renderer_attached(function() called = true end)
      assert.is_true(called)
      assert.is_true(component._renderer_attached)
    end)

    it('should not call attach_fn on subsequent calls', function()
      local call_count = 0
      local fn = function() call_count = call_count + 1 end
      component:ensure_renderer_attached(fn)
      component:ensure_renderer_attached(fn)
      component:ensure_renderer_attached(fn)
      eq(1, call_count)
    end)
  end)

  describe('inheritance', function()
    it('should be an instance of Component', function()
      -- ViewportComponent instances should have all Component lifecycle methods
      assert.is_not_nil(component.mount)
      assert.is_not_nil(component.unmount)
      assert.is_not_nil(component.set_props)
      assert.is_not_nil(component.set_state)
      assert.is_not_nil(component.with_element)
    end)

    it('should support full lifecycle', function()
      component:mount()
      component:set_state({ x = 1 })
      component:unmount()
      eq({ 'render' }, component._log)
      assert.is_false(component.mounted)
    end)
  end)
end)
