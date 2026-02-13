local eq = assert.are.same

describe('BlameInfoComponent:', function()
  local BlameInfoComponent

  before_each(function()
    BlameInfoComponent = require('vgit.ui.components.BlameInfoComponent')
  end)

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
      local mock_element = { type = 'element' }
      local instance = {
        props = {},
        state = { blame = nil },
        mounted = false,
        _needs_update = false,
        _element = mock_element,
      }
      setmetatable(instance, BlameInfoComponent)

      local spec = instance:get_layout_spec()

      assert.is_not_nil(spec)
      eq('view', spec.type)
      eq(3, spec.height)
      eq(mock_element, spec.view)
    end)
  end)

  describe('component_will_mount', function()
    it('should create an element', function()
      local instance = BlameInfoComponent({})
      instance:component_will_mount()

      assert.is_not_nil(instance._element)
    end)
  end)

  describe('component_did_mount', function()
    it('should call render', function()
      local render_called = false
      local instance = {
        props = {},
        state = { blame = nil },
        mounted = false,
        _needs_update = false,
      }
      setmetatable(instance, BlameInfoComponent)

      instance.render = function() render_called = true end
      instance:component_did_mount()

      assert.is_true(render_called)
    end)
  end)
end)
