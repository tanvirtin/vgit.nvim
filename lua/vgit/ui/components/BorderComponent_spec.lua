local eq = assert.are.same

describe('BorderComponent:', function()
  local BorderComponent

  before_each(function()
    BorderComponent = require('vgit.ui.components.BorderComponent')
  end)

  describe('constructor', function()
    it('should create via Component.constructor', function()
      local instance = BorderComponent({ winhl = 'Normal:Test' })

      assert.is_not_nil(instance)
      assert.is_not_nil(instance.props)
      eq('Normal:Test', instance.props.winhl)
    end)

    it('should create with empty props', function()
      local instance = BorderComponent({})

      assert.is_not_nil(instance)
      assert.is_table(instance.props)
    end)
  end)

  describe('render', function()
    it('should be a no-op and return nil', function()
      local instance = {
        props = {},
        state = {},
        mounted = false,
        _needs_update = false,
      }
      setmetatable(instance, BorderComponent)

      assert.is_nil(instance:render())
    end)
  end)

  describe('get_layout_spec', function()
    it('should return a view spec with height 1', function()
      local mock_element = { type = 'element' }
      local instance = {
        props = {},
        state = {},
        mounted = false,
        _needs_update = false,
        _element = mock_element,
      }
      setmetatable(instance, BorderComponent)

      local spec = instance:get_layout_spec()

      assert.is_not_nil(spec)
      eq('view', spec.type)
      eq(1, spec.height)
      eq(mock_element, spec.view)
    end)
  end)

  describe('component_will_mount', function()
    it('should use default winhl when none provided', function()
      local instance = BorderComponent({})
      instance:component_will_mount()

      assert.is_not_nil(instance._element)
    end)

    it('should use custom winhl from props', function()
      local instance = BorderComponent({ winhl = 'Normal:CustomHL' })
      instance:component_will_mount()

      assert.is_not_nil(instance._element)
    end)
  end)

  describe('component_did_mount', function()
    it('should call render', function()
      local render_called = false
      local instance = {
        props = {},
        state = {},
        mounted = false,
        _needs_update = false,
      }
      setmetatable(instance, BorderComponent)

      instance.render = function() render_called = true end
      instance:component_did_mount()

      assert.is_true(render_called)
    end)
  end)
end)
