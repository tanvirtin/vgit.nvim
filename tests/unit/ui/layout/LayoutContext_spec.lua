local eq = assert.are.same

describe('LayoutContext', function()
  local LayoutContext

  before_each(function()
    LayoutContext = require('vgit.ui.layout.LayoutContext')
  end)

  describe('convert_dimension', function()
    it('should return nil for nil value', function()
      eq(nil, LayoutContext.convert_dimension(nil))
    end)

    it('should floor numbers', function()
      eq(42, LayoutContext.convert_dimension(42))
      eq(10, LayoutContext.convert_dimension(10.7))
      eq(0, LayoutContext.convert_dimension(0))
    end)

    it('should convert percentages with parent dimension', function()
      eq(50, LayoutContext.convert_dimension('50%', 100))
      eq(25, LayoutContext.convert_dimension('25%', 100))
      eq(150, LayoutContext.convert_dimension('75%', 200))
    end)

    it('should floor percentage results', function()
      eq(33, LayoutContext.convert_dimension('33%', 100))
      eq(66, LayoutContext.convert_dimension('66%', 100))
    end)

    it('should return nil for percentage without parent dimension', function()
      assert.is_nil(LayoutContext.convert_dimension('50%', nil))
    end)

    it('should convert vh values', function()
      local result = LayoutContext.convert_dimension('50vh')
      assert.is_number(result)
      assert.is_true(result > 0)
    end)

    it('should convert vw values', function()
      local result = LayoutContext.convert_dimension('50vw')
      assert.is_number(result)
      assert.is_true(result > 0)
    end)

    it('should handle 100vh', function()
      local result = LayoutContext.convert_dimension('100vh')
      assert.is_number(result)
      eq(vim.o.lines, result)
    end)

    it('should handle 100vw', function()
      local result = LayoutContext.convert_dimension('100vw')
      assert.is_number(result)
      eq(vim.o.columns, result)
    end)
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

  describe('derive', function()
    it('should create a new context with overridden values', function()
      local ctx = LayoutContext({
        mode = 'screen',
        width = '100vw',
        height = '100vh',
        zindex = 1,
      })

      local derived = ctx:derive({ mode = 'popup', zindex = 5 })

      assert.is_true(derived:is_popup_mode())
      eq(5, derived.zindex)
      eq('100vw', derived.width)
      eq('100vh', derived.height)
    end)

    it('should preserve original values when no overrides', function()
      local ctx = LayoutContext({
        mode = 'screen',
        width = '50vw',
        height = '50vh',
        zindex = 3,
      })

      local derived = ctx:derive({})

      eq('screen', derived.mode)
      eq('50vw', derived.width)
      eq('50vh', derived.height)
      eq(3, derived.zindex)
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
