local eq = assert.are.same

describe('CompositeComponent:', function()
  local CompositeComponent
  local ElementComponent

  before_each(function()
    CompositeComponent = require('vgit.ui.CompositeComponent')
    ElementComponent = require('vgit.ui.ElementComponent')
  end)

  local function with_children(classes)
    local Subclass = CompositeComponent:extend()

    function Subclass:get_child_classes()
      return classes
    end

    return Subclass
  end

  it('has no children until it is mounted', function()
    eq({}, CompositeComponent({}).children)
  end)

  it('builds one child per class its subclass names, with empty props, once', function()
    local instance = with_children({ left = ElementComponent, right = ElementComponent })({})

    instance:mount()

    local left = instance.children.left

    assert.is_true(instance.children.right:is(ElementComponent))
    assert.is_table(left.props)
    instance:mount()
    assert.are.equal(left, instance.children.left)
  end)

  it('unmounts its children after on_unmount, and forgets them', function()
    local Subclass = with_children({ only = ElementComponent })
    local order = {}

    function Subclass:on_unmount()
      order[#order + 1] = 'hook:' .. tostring(self.children.only ~= nil)
    end

    local instance = Subclass({})

    instance:mount()

    local child = instance.children.only

    child._mounted = true
    instance:unmount()

    eq({ 'hook:true' }, order)
    eq(false, child._mounted)
    eq({}, instance.children)
    eq(false, instance:is_mounted())
  end)

  it('asks its subclass for the layout', function()
    local Subclass = with_children({ left = ElementComponent, right = ElementComponent })

    function Subclass:layout(spec)
      return spec.horizontal({
        spec.view(self.children.left, { flex = 1 }),
        spec.view(self.children.right, { flex = 1 }),
      })
    end

    local instance = Subclass({})

    instance:mount()

    local spec = instance:get_layout_spec()

    eq('flex', spec.type)
    eq(2, #spec.children)
  end)
end)
