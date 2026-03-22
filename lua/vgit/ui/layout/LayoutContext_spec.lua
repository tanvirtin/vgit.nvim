local eq = assert.are.same

describe('LayoutContext:', function()
  local LayoutContext

  before_each(function()
    LayoutContext = require('vgit.ui.layout.LayoutContext')
  end)

  describe('mode methods', function()
    it('should identify screen mode', function()
      local ctx = LayoutContext({ mode = 'screen' })
      assert.is_true(ctx:is_screen_mode())
      assert.is_false(ctx:is_popup_mode())
      assert.is_false(ctx:is_lens_mode())
      assert.is_false(ctx:is_floating_mode())
    end)

    it('should identify popup mode', function()
      local ctx = LayoutContext({ mode = 'popup' })
      assert.is_false(ctx:is_screen_mode())
      assert.is_true(ctx:is_popup_mode())
      assert.is_false(ctx:is_lens_mode())
      assert.is_true(ctx:is_floating_mode())
    end)

    it('should identify lens mode', function()
      local ctx = LayoutContext({ mode = 'lens' })
      assert.is_false(ctx:is_screen_mode())
      assert.is_false(ctx:is_popup_mode())
      assert.is_true(ctx:is_lens_mode())
      assert.is_true(ctx:is_floating_mode())
    end)

    it('should default to popup mode', function()
      local ctx = LayoutContext({})
      assert.is_true(ctx:is_popup_mode())
    end)
  end)

  describe('get_props_for_component', function()
    it('should return expected props', function()
      local ctx = LayoutContext({
        mode = 'popup',
        width = 200,
        height = 100,
        zindex = 3,
      })

      local props = ctx:get_props_for_component()

      eq('popup', props.mode)
      eq(3, props.zindex)
      assert.is_not_nil(props.dimensions)
    end)
  end)

  describe('get_dimensions', function()
    it('should cache dimensions', function()
      local ctx = LayoutContext({
        width = 100,
        height = 50,
      })

      local dims1 = ctx:get_dimensions()
      local dims2 = ctx:get_dimensions()

      eq(dims1, dims2)
      eq(100, dims1.width)
      eq(50, dims1.height)
    end)
  end)
end)
