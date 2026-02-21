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
      local instance = BorderComponent({})

      assert.is_nil(instance:render())
    end)
  end)

  describe('get_layout_spec', function()
    it('should return a view spec with height 1', function()
      local instance = mount_component()

      local spec = instance:get_layout_spec()

      assert.is_not_nil(spec)
      eq('view', spec.type)
      eq(1, spec.height)
      eq(instance._element, spec.view)
    end)
  end)

  describe('component_will_mount', function()
    it('should create a valid Neovim window with default winhl', function()
      local instance = mount_component()

      assert.is_not_nil(instance._element)
      assert.is_truthy(instance._element:is_valid())
    end)

    it('should create a valid Neovim window with custom winhl', function()
      local instance = mount_component({ winhl = 'Normal:CustomHL' })

      assert.is_not_nil(instance._element)
      assert.is_truthy(instance._element:is_valid())
    end)
  end)

  describe('component_did_mount', function()
    it('should call render', function()
      local render_called = false
      local instance = mount_component()

      instance.render = function() render_called = true end
      instance:component_did_mount()

      assert.is_true(render_called)
    end)
  end)
end)
