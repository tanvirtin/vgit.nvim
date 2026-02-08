local ComponentGroup = require('vgit.ui.ComponentGroup')

local function mock_component(name)
  return {
    name = name,
    mounted = false,
    props = {},
    _log = {},
    mount = function(self)
      self.mounted = true
      table.insert(self._log, 'mount')
    end,
    unmount = function(self)
      self.mounted = false
      table.insert(self._log, 'unmount')
    end,
    component_did_mount = function(self)
      table.insert(self._log, 'did_mount')
    end,
    on = function(self, event, cb)
      table.insert(self._log, 'on:' .. event)
    end,
    set_keymap = function(self, config, handler)
      table.insert(self._log, 'set_keymap:' .. (config.key or '?'))
    end,
  }
end

local function mock_renderer_with_context(context_props)
  return {
    context = {
      get_props_for_component = function()
        return context_props
      end,
    },
  }
end

describe('ComponentGroup', function()
  local group

  before_each(function()
    group = ComponentGroup()
  end)

  describe('mount', function()
    it('should mount a component and add to list', function()
      local c = mock_component('a')
      group:mount(c, {})
      assert.is_true(c.mounted)
      assert.are.same({ 'mount' }, c._log)
      assert.are.equal(1, #group:get_mounted_components())
    end)

    it('should skip already mounted component', function()
      local c = mock_component('a')
      c.mounted = true
      group:mount(c, {})
      assert.are.same({}, c._log)
      assert.are.equal(0, #group:get_mounted_components())
    end)

    it('should inject context props without overwriting existing props', function()
      local c = mock_component('a')
      c.props = { mode = 'custom' }
      local renderer = mock_renderer_with_context({ mode = 'popup', zindex = 2 })
      group:mount(c, renderer)
      assert.are.equal('custom', c.props.mode)
      assert.are.equal(2, c.props.zindex)
    end)

    it('should inject context props when component has no existing props', function()
      local c = mock_component('a')
      c.props = nil
      local renderer = mock_renderer_with_context({ mode = 'popup', zindex = 5 })
      group:mount(c, renderer)
      assert.are.equal('popup', c.props.mode)
      assert.are.equal(5, c.props.zindex)
    end)

    it('should work without renderer context', function()
      local c = mock_component('a')
      group:mount(c, {})
      assert.is_true(c.mounted)
    end)

    it('should mount multiple components in order', function()
      local a = mock_component('a')
      local b = mock_component('b')
      group:mount(a, {})
      group:mount(b, {})
      local mounted = group:get_mounted_components()
      assert.are.equal(2, #mounted)
      assert.are.equal('a', mounted[1].name)
      assert.are.equal('b', mounted[2].name)
    end)
  end)

  describe('call_did_mount', function()
    it('should call component_did_mount on all mounted components', function()
      local a = mock_component('a')
      local b = mock_component('b')
      group:mount(a, {})
      group:mount(b, {})
      group:call_did_mount()
      assert.are.same({ 'mount', 'did_mount' }, a._log)
      assert.are.same({ 'mount', 'did_mount' }, b._log)
    end)

    it('should handle components without component_did_mount method', function()
      local c = { mounted = false, props = {}, mount = function(self) self.mounted = true end }
      group:mount(c, {})
      assert.has_no.errors(function()
        group:call_did_mount()
      end)
    end)
  end)

  describe('unmount', function()
    it('should unmount all components and clear the list', function()
      local a = mock_component('a')
      local b = mock_component('b')
      group:mount(a, {})
      group:mount(b, {})
      group:unmount()
      assert.is_false(a.mounted)
      assert.is_false(b.mounted)
      assert.are.equal(0, #group:get_mounted_components())
    end)
  end)

  describe('is_mounted', function()
    it('should return true for a mounted component', function()
      local c = mock_component('a')
      group:mount(c, {})
      assert.is_true(group:is_mounted(c))
    end)

    it('should return false for a component not in the group', function()
      local c = mock_component('a')
      assert.is_false(group:is_mounted(c))
    end)

    it('should return false after unmount', function()
      local c = mock_component('a')
      group:mount(c, {})
      group:unmount()
      assert.is_false(group:is_mounted(c))
    end)
  end)

  describe('on', function()
    it('should delegate event to all mounted components', function()
      local a = mock_component('a')
      local b = mock_component('b')
      group:mount(a, {})
      group:mount(b, {})
      group:on('BufEnter', function() end)
      assert.are.same({ 'mount', 'on:BufEnter' }, a._log)
      assert.are.same({ 'mount', 'on:BufEnter' }, b._log)
    end)
  end)

  describe('set_keymap', function()
    it('should delegate keymap configs to all mounted components', function()
      local a = mock_component('a')
      local b = mock_component('b')
      group:mount(a, {})
      group:mount(b, {})
      group:set_keymap({
        { key = 'q', handler = function() end },
        { key = 'j', handler = function() end },
      })
      assert.are.same({ 'mount', 'set_keymap:q', 'set_keymap:j' }, a._log)
      assert.are.same({ 'mount', 'set_keymap:q', 'set_keymap:j' }, b._log)
    end)
  end)
end)
