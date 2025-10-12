local spy = require('luassert.spy')
local Renderer = require('vgit.ui.Renderer')
local Component = require('vgit.ui.Component')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

describe('V2 Renderer', function()
  local renderer
  local TestComponent
  local component

  before_each(function()
    TestComponent = Component:extend()

    function TestComponent:render()
      return LayoutSpec.container(LayoutSpec.view({ lines = { 'test line' } }, { id = 'body', flex = 1 }))
    end

    component = TestComponent()
  end)

  after_each(function()
    if renderer then
      renderer:destroy()
      renderer = nil
    end
    collectgarbage('collect')
  end)

  describe('constructor', function()
    it('should initialize with defaults', function()
      renderer = Renderer()

      assert.is_nil(renderer.layout_renderer)
      assert.is_nil(renderer.root_component)
      assert.is_nil(renderer.context)
      assert.is_not_nil(renderer.component_tree)
      assert.is_false(renderer.is_destroying)
    end)
  end)

  describe('render', function()
    it('should error without layout_config', function()
      renderer = Renderer()

      assert.has_error(function()
        renderer:render(nil)
      end, 'Renderer:render() requires layout_config')
    end)

    it('should error without component', function()
      renderer = Renderer()

      assert.has_error(function()
        renderer:render({})
      end, 'Renderer:render() requires layout_config.component')
    end)

    it('should create LayoutContext from layout_config', function()
      renderer = Renderer()

      renderer:render({
        component = component,
        mode = 'lens',
        width = '80vw',
        height = '40vh',
        zindex = 5,
      })

      assert.is_not_nil(renderer.context)
      assert.are.same('lens', renderer.context.mode)
      assert.are.same('80vw', renderer.context.width)
      assert.are.same('40vh', renderer.context.height)
      assert.are.same(5, renderer.context.zindex)
    end)

    it('should use default values for missing config', function()
      renderer = Renderer()

      renderer:render({
        component = component,
      })

      assert.is_not_nil(renderer.context)
      assert.are.same('popup', renderer.context.mode)
      assert.are.same(2, renderer.context.zindex)
    end)

    it('should mount component with lifecycle manager', function()
      renderer = Renderer()
      local mount_spy = spy.on(renderer.component_tree, 'mount')

      renderer:render({
        component = component,
        mode = 'screen',
      })

      assert.spy(mount_spy).was.called(1)
      -- The component gets modified during render, so we just check it was called
      -- with the lifecycle manager and some component and renderer
      -- We can't check exact arguments because the component gets modified during render
    end)

    it('should inject layout_config into component props', function()
      renderer = Renderer()

      local layout_config = {
        component = component,
        mode = 'popup',
        custom_prop = 'value',
      }

      renderer:render(layout_config)

      assert.is_not_nil(component.props.layout_config)
      assert.are.same(layout_config, component.props.layout_config)
    end)

    it('should call component_did_mount after render', function()
      renderer = Renderer()
      component.component_did_mount = spy.new(function() end)

      renderer:render({
        component = component,
        mode = 'screen',
      })

      vim.wait(10)
      assert.spy(component.component_did_mount).was.called()
    end)

    it('should return self for chaining', function()
      renderer = Renderer()

      local result = renderer:render({
        component = component,
        mode = 'screen',
      })

      assert.are.same(renderer, result)
    end)
  end)

  describe('unmount', function()
    it('should unmount all components via lifecycle manager', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      local unmount_spy = spy.on(renderer.component_tree, 'unmount_all')
      renderer:unmount()

      assert.spy(unmount_spy).was.called(1)
    end)

    it('should destroy layout renderer', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      assert.is_not_nil(renderer.layout_renderer)
      renderer:unmount()

      assert.is_nil(renderer.layout_renderer)
    end)

    it('should clear root component', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      assert.is_not_nil(renderer.root_component)
      renderer:unmount()

      assert.is_nil(renderer.root_component)
    end)

    it('should prevent double unmount', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      renderer:unmount()

      assert.has_no.errors(function()
        renderer:unmount()
      end)
    end)
  end)

  describe('destroy', function()
    it('should call unmount', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      local unmount_spy = spy.on(renderer, 'unmount')
      renderer:destroy()

      assert.spy(unmount_spy).was.called(1)
    end)
  end)

  describe('event delegation', function()
    it('should delegate on() to layout_renderer', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      if renderer.layout_renderer then
        local on_spy = spy.on(renderer.layout_renderer, 'on')

        local callback = function() end
        renderer:on('test_event', callback)

        assert.spy(on_spy).was.called(1)
        assert.spy(on_spy).was.called_with(renderer.layout_renderer, 'test_event', callback)
      end
    end)

    it('should delegate set_keymap() to layout_renderer', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      if renderer.layout_renderer then
        local keymap_spy = spy.on(renderer.layout_renderer, 'set_keymap')

        local configs = { { key = 'q', mode = 'n' } }
        renderer:set_keymap(configs)

        assert.spy(keymap_spy).was.called(1)
        assert.spy(keymap_spy).was.called_with(renderer.layout_renderer, configs)
      end
    end)

    it('should return self for chaining', function()
      renderer = Renderer()
      renderer:render({
        component = component,
        mode = 'screen',
      })

      local result1 = renderer:on('event', function() end)
      local result2 = renderer:set_keymap({})

      assert.are.same(renderer, result1)
      assert.are.same(renderer, result2)
    end)
  end)
end)
