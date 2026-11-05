local ui_helper = require('tests.helpers.ui')
local eq = assert.are.same

describe('ElementComponent:', function()
  local ElementComponent

  before_each(function()
    ElementComponent = require('vgit.ui.ElementComponent')
  end)

  after_each(ui_helper.cleanup_ui)

  local function mounted(component)
    ui_helper.mount({ component = component, mode = 'popup', width = 40, height = 20 })

    return component
  end

  it('has no element until it is mounted, and answers harmlessly meanwhile', function()
    local instance = ElementComponent({})

    assert.is_nil(instance._element)
    eq(false, instance:is_valid())
    eq(false, instance:is_focused())
    assert.is_nil(instance:get_lines())
    eq(instance, instance:set_lines({ 'a' }))
    assert.is_function(instance:on_click(1))
  end)

  it('creates its element from the hooks a subclass overrides', function()
    local Subclass = ElementComponent:extend()

    function Subclass:get_buf_options()
      return { modifiable = true }
    end

    function Subclass:get_win_options()
      return { cursorline = false }
    end

    local instance = mounted(Subclass({}))

    eq(true, instance:is_valid())
    eq(true, instance._element:get_buffer():get_option('modifiable'))
  end)

  it('lets props override what the hooks say, and set the filetype', function()
    local instance = mounted(ElementComponent({ filetype = 'lua', buf_options = { modifiable = true } }))

    eq('lua', instance:get_filetype())
    eq(true, instance._element:get_buffer():get_option('modifiable'))
  end)

  it('forwards to its element and returns itself, so calls chain', function()
    local Subclass = ElementComponent:extend()

    function Subclass:get_buf_options()
      return { modifiable = true }
    end

    local instance = mounted(Subclass({}))

    eq(instance, instance:set_lines({ 'one', 'two' }))
    eq({ 'one', 'two' }, instance:get_lines())
    eq(2, instance:get_line_count())
    eq(instance, instance:clear_lines())
    eq(1, instance:get_line_count())
  end)

  it('runs on_unmount before it lets go of the element', function()
    local Subclass = ElementComponent:extend()
    local seen

    function Subclass:on_unmount()
      seen = self:is_valid()
    end

    local instance = mounted(Subclass({}))

    instance:unmount()

    eq(true, seen)
    assert.is_nil(instance._element)
    eq(false, instance:is_mounted())
  end)

  it('reports the props it had before an update to on_props, once it is mounted', function()
    local Subclass = ElementComponent:extend()
    local before

    function Subclass:on_props(prev)
      before = prev
    end

    local instance = Subclass({ a = 1 })

    instance:set_props({ a = 2 })
    assert.is_nil(before)

    mounted(instance)
    instance:set_props({ a = 3 })

    eq({ a = 2 }, { a = before.a })
    eq(3, instance.props.a)
  end)

  it('lays itself out with the options its subclass asks for', function()
    local Subclass = ElementComponent:extend()

    function Subclass:get_layout_opts()
      return { height = 3 }
    end

    local spec = mounted(Subclass({})):get_layout_spec()

    eq(3, spec.layout_opts and spec.layout_opts.height or spec.height)
  end)
end)
