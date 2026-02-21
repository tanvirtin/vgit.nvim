local eq = assert.are.same

describe('LayoutComponent:', function()
  local LayoutComponent

  before_each(function()
    LayoutComponent = require('vgit.ui.components.LayoutComponent')
  end)

  describe('render', function()
    it('should be a no-op', function()
      local instance = LayoutComponent({})

      assert.is_nil(instance:render())
    end)
  end)

  describe('get_layout_spec', function()
    it('should return props.spec passthrough', function()
      local spec = { type = 'view', height = 10 }
      local instance = LayoutComponent({ spec = spec })

      eq(spec, instance:get_layout_spec())
    end)

    it('should return nil when props.spec is nil', function()
      local instance = LayoutComponent({})

      assert.is_nil(instance:get_layout_spec())
    end)
  end)

  describe('component_did_mount', function()
    it('should call render', function()
      local render_called = false
      local instance = LayoutComponent({})

      instance.render = function() render_called = true end
      instance:component_did_mount()

      assert.is_true(render_called)
    end)
  end)
end)
