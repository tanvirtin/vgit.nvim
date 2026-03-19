local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('BorderComponent:', function()
  local BorderComponent
  local ComponentManager

  before_each(function()
    BorderComponent = require('vgit.ui.components.BorderComponent')
    ComponentManager = require('vgit.ui.ComponentManager')
  end)

  after_each(ui_helper.cleanup_ui)

  local function mount_component(props)
    local component = BorderComponent(props or {})
    ComponentManager():render({ component = component, mode = 'popup', width = 40, height = 20 })
    return component
  end

  describe('constructor', function()
    it('should create with winhl prop', function()
      local instance = BorderComponent({ winhl = 'Normal:Test' })

      assert.is_not_nil(instance)
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
      local instance = BorderComponent({})

      assert.is_nil(instance:render())
    end)
  end)

  describe('get_layout_spec', function()
    it('should return a view spec with height 1', function()
      local instance = mount_component()
      local spec = instance:get_layout_spec()

      eq('view', spec.type)
      eq(1, spec.height)
      eq(instance._element, spec.view)
    end)
  end)

  describe('mount', function()
    it('should create a valid element with default winhl', function()
      local instance = mount_component()

      assert.is_not_nil(instance._element)
      assert.is_truthy(instance._element:is_valid())
    end)

    it('should create a valid element with custom winhl', function()
      local instance = mount_component({ winhl = 'Normal:CustomHL' })

      assert.is_not_nil(instance._element)
      assert.is_truthy(instance._element:is_valid())
    end)
  end)

  describe('unmount', function()
    it('should clean up element', function()
      local instance = mount_component()
      instance:unmount()

      assert.is_nil(instance._element)
      assert.is_false(instance:is_mounted())
    end)

    it('should be safe to call twice', function()
      local instance = mount_component()
      instance:unmount()
      instance:unmount()

      assert.is_nil(instance._element)
    end)
  end)
end)
