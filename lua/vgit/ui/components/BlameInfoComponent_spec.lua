local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('BlameInfoComponent:', function()
  local BlameInfoComponent
  local ComponentManager

  before_each(function()
    BlameInfoComponent = require('vgit.ui.components.BlameInfoComponent')
    ComponentManager = require('vgit.ui.ComponentManager')
  end)

  after_each(ui_helper.cleanup_ui)

  local function mount_component(props)
    local component = BlameInfoComponent(props or {})
    ComponentManager():render({ component = component, mode = 'popup', width = 40, height = 20 })
    return component
  end

  describe('constructor', function()
    it('should create via Component.constructor', function()
      local instance = BlameInfoComponent({})

      assert.is_not_nil(instance)
      assert.is_table(instance.props)
    end)

    it('should preserve props', function()
      local instance = BlameInfoComponent({ blame = 'test' })

      eq('test', instance.props.blame)
    end)
  end)

  describe('get_initial_state', function()
    it('should return table with blame = nil', function()
      local instance = BlameInfoComponent({})

      assert.is_table(instance.state)
      assert.is_nil(instance.state.blame)
    end)
  end)

  describe('get_layout_spec', function()
    it('should return a view spec with height 3', function()
      local instance = mount_component()

      local spec = instance:get_layout_spec()

      assert.is_not_nil(spec)
      eq('view', spec.type)
      eq(3, spec.height)
      eq(instance._element, spec.view)
    end)
  end)

  describe('component_will_mount', function()
    it('should create a valid Neovim window', function()
      local instance = mount_component()

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
