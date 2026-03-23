local ComponentGroup = require('vgit.ui.ComponentGroup')
local ui_helper = require('tests.helpers.ui')
local TestComponent = ui_helper.TestComponent
local cleanup_ui = ui_helper.cleanup_ui
local count_floating_windows = ui_helper.count_floating_windows

local eq = assert.are.same

local function mock_renderer_with_context(context_props)
  return {
    get_context = function()
      return {
        get_props_for_component = function()
          return context_props
        end,
      }
    end,
  }
end

describe('ComponentGroup:', function()
  local group

  before_each(function()
    group = ComponentGroup()
  end)

  after_each(function()
    cleanup_ui()
  end)

  describe('mount', function()
    it('should mount a component and add to list', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      assert.is_true(c._mounted)
      assert.are.equal(1, #group:get_mounted_components())
    end)

    it('should skip already mounted component', function()
      local c = TestComponent({ name = 'a' })
      c._mounted = true
      group:mount(c, {})
      eq({}, c._log)
      assert.are.equal(0, #group:get_mounted_components())
    end)

    it('should inject context props without overwriting existing props', function()
      local c = TestComponent({ name = 'a', mode = 'custom' })
      local renderer = mock_renderer_with_context({ mode = 'popup', zindex = 2 })
      group:mount(c, renderer)
      assert.are.equal('custom', c.props.mode)
      assert.are.equal(2, c.props.zindex)
    end)

    it('should inject context props when component has no existing props', function()
      local c = TestComponent({ name = 'a' })
      c.props = nil
      local renderer = mock_renderer_with_context({ mode = 'popup', zindex = 5 })
      group:mount(c, renderer)
      assert.are.equal('popup', c.props.mode)
      assert.are.equal(5, c.props.zindex)
    end)

    it('should work without renderer context', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      assert.is_true(c._mounted)
    end)

    it('should mount multiple components in order', function()
      local a = TestComponent({ name = 'a' })
      local b = TestComponent({ name = 'b' })
      group:mount(a, {})
      group:mount(b, {})
      local mounted = group:get_mounted_components()
      assert.are.equal(2, #mounted)
      assert.are.equal('a', mounted[1].props.name)
      assert.are.equal('b', mounted[2].props.name)
    end)

    it('should create element during mount', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      assert.is_not_nil(c._element)
    end)
  end)

  describe('call_did_mount', function()
    it('should call component_did_mount on all mounted components', function()
      local a = TestComponent({ name = 'a' })
      local b = TestComponent({ name = 'b' })
      group:mount(a, {})
      group:mount(b, {})
      group:call_did_mount()
      eq({ 'did_mount' }, a._log)
      eq({ 'did_mount' }, b._log)
    end)
  end)

  describe('unmount', function()
    it('should unmount all components and clear the list', function()
      local a = TestComponent({ name = 'a' })
      local b = TestComponent({ name = 'b' })
      group:mount(a, {})
      group:mount(b, {})
      group:unmount()
      assert.is_false(a._mounted)
      assert.is_false(b._mounted)
      assert.are.equal(0, #group:get_mounted_components())
    end)

    it('should clean up elements on unmount', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      -- Mount element to create a real floating window
      c._element._plot.win_plot.relative = 'editor'
      c._element._plot.win_plot.width = 10
      c._element._plot.win_plot.height = 5
      c._element._plot.win_plot.row = 0
      c._element._plot.win_plot.col = 0
      c._element:mount()
      assert.is_true(count_floating_windows() >= 1)
      group:unmount()
      assert.are.equal(0, count_floating_windows())
    end)
  end)

  describe('is_mounted', function()
    it('should return true for a mounted component', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      assert.is_true(group:is_mounted(c))
    end)

    it('should return false for a component not in the group', function()
      local c = TestComponent({ name = 'a' })
      assert.is_false(group:is_mounted(c))
    end)

    it('should return false after unmount', function()
      local c = TestComponent({ name = 'a' })
      group:mount(c, {})
      group:unmount()
      assert.is_false(group:is_mounted(c))
    end)
  end)

  describe('on', function()
    it('should delegate event to all mounted components with real elements', function()
      local a = TestComponent({ name = 'a' })
      local b = TestComponent({ name = 'b' })
      group:mount(a, {})
      group:mount(b, {})
      -- Mount elements so on() can register events on real buffers
      a._element._plot.win_plot.relative = 'editor'
      a._element._plot.win_plot.width = 10
      a._element._plot.win_plot.height = 5
      a._element._plot.win_plot.row = 0
      a._element._plot.win_plot.col = 0
      b._element._plot.win_plot.relative = 'editor'
      b._element._plot.win_plot.width = 10
      b._element._plot.win_plot.height = 5
      b._element._plot.win_plot.row = 0
      b._element._plot.win_plot.col = 0
      a._element:mount()
      b._element:mount()
      assert.has_no.errors(function()
        group:on('BufEnter', function() end)
      end)
    end)
  end)

  describe('set_keymap', function()
    it('should delegate keymap configs to all mounted components with real elements', function()
      local a = TestComponent({ name = 'a' })
      local b = TestComponent({ name = 'b' })
      group:mount(a, {})
      group:mount(b, {})
      -- Mount elements so set_keymap() can register on real buffers
      a._element._plot.win_plot.relative = 'editor'
      a._element._plot.win_plot.width = 10
      a._element._plot.win_plot.height = 5
      a._element._plot.win_plot.row = 0
      a._element._plot.win_plot.col = 0
      b._element._plot.win_plot.relative = 'editor'
      b._element._plot.win_plot.width = 10
      b._element._plot.win_plot.height = 5
      b._element._plot.win_plot.row = 0
      b._element._plot.win_plot.col = 0
      a._element:mount()
      b._element:mount()
      assert.has_no.errors(function()
        group:set_keymap({
          { mode = 'n', key = 'q', handler = function() end },
          { mode = 'n', key = 'j', handler = function() end },
        })
      end)
    end)
  end)
end)
