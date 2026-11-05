local eq = assert.are.same

describe('CompositeComponent:', function()
  local CompositeComponent
  local ElementComponent

  before_each(function()
    CompositeComponent = require('vgit.ui.CompositeComponent')
    ElementComponent = require('vgit.ui.ElementComponent')
  end)

  it('has no children until it is mounted', function()
    eq({}, CompositeComponent({}).children)
  end)

  it('builds one child per class its subclass names, once', function()
    local Subclass = CompositeComponent:extend()

    function Subclass:get_child_classes()
      return { left = ElementComponent, right = ElementComponent }
    end

    local instance = Subclass({})

    instance:mount()

    local left = instance.children.left

    assert.is_true(instance.children.right:is(ElementComponent))
    instance:mount()
    assert.are.equal(left, instance.children.left)
  end)

  it('unmounts its children after on_unmount, and forgets them', function()
    local Subclass = CompositeComponent:extend()
    local order = {}

    function Subclass:get_child_classes()
      return { only = ElementComponent }
    end

    function Subclass:on_unmount()
      order[#order + 1] = 'hook:' .. tostring(self.children.only ~= nil)
    end

    local instance = Subclass({})

    instance:mount()
    instance:unmount()

    eq({ 'hook:true' }, order)
    eq({}, instance.children)
    eq(false, instance:is_mounted())
  end)

  it('asks its subclass for the layout', function()
    local Subclass = CompositeComponent:extend()

    function Subclass:layout(spec)
      return spec.vertical({})
    end

    eq('flex', Subclass({}):get_layout_spec().type)
  end)
end)
