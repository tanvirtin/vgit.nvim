local LayoutContext = require('vgit.ui.layout.LayoutContext')

describe('LayoutContext', function()
  local context

  describe('constructor', function()
    it('should create with default values', function()
      context = LayoutContext()

      assert.are.same('popup', context.mode)
      assert.are.same(2, context.zindex)
      assert.are.same('editor', context.relative)
      assert.are.same('center', context.position)
      assert.is_nil(context._cached_dims)
    end)

    it('should accept custom configuration', function()
      context = LayoutContext({
        mode = 'lens',
        width = '80vw',
        height = '60vh',
        zindex = 5,
        relative = 'cursor',
        position = 'top',
      })

      assert.are.same('lens', context.mode)
      assert.are.same('80vw', context.width)
      assert.are.same('60vh', context.height)
      assert.are.same(5, context.zindex)
      assert.are.same('cursor', context.relative)
      assert.are.same('top', context.position)
    end)
  end)

  describe('mode predicates', function()
    it('should identify screen mode', function()
      context = LayoutContext({ mode = 'screen' })
      assert.is_true(context:is_screen_mode())
      assert.is_false(context:is_lens_mode())
      assert.is_false(context:is_popup_mode())
      assert.is_false(context:is_floating_mode())
    end)

    it('should identify lens mode', function()
      context = LayoutContext({ mode = 'lens' })
      assert.is_false(context:is_screen_mode())
      assert.is_true(context:is_lens_mode())
      assert.is_false(context:is_popup_mode())
      assert.is_true(context:is_floating_mode())
    end)

    it('should identify popup mode', function()
      context = LayoutContext({ mode = 'popup' })
      assert.is_false(context:is_screen_mode())
      assert.is_false(context:is_lens_mode())
      assert.is_true(context:is_popup_mode())
      assert.is_true(context:is_floating_mode())
    end)
  end)

  describe('dimension conversion', function()
    before_each(function()
      -- Mock vim.o for dimension tests
      vim.o.columns = 200
      vim.o.lines = 50
    end)

    it('should cache converted dimensions', function()
      context = LayoutContext({
        width = '80vw',
        height = '60vh',
      })

      local dims1 = context:get_dimensions()
      local dims2 = context:get_dimensions()

      assert.are.same(dims1, dims2)
      assert.are.same(context._cached_dims, dims1)
    end)

    it('should convert viewport width (vw)', function()
      context = LayoutContext({ width = '80vw' })
      local dims = context:get_dimensions()

      -- 80% of 200 columns = 160
      assert.are.same(160, dims.width)
    end)

    it('should convert viewport height (vh)', function()
      context = LayoutContext({ height = '60vh' })
      local dims = context:get_dimensions()

      -- 60% of 50 lines = 30
      assert.are.same(30, dims.height)
    end)

    it('should handle numeric dimensions', function()
      context = LayoutContext({
        width = 100,
        height = 50,
      })

      local dims = context:get_dimensions()
      assert.are.same(100, dims.width)
      assert.are.same(50, dims.height)
    end)
  end)

  describe('derive', function()
    it('should create new context with overrides', function()
      context = LayoutContext({
        mode = 'popup',
        width = 100,
        height = 50,
        zindex = 2,
      })

      local derived = context:derive({
        mode = 'lens',
        width = 200,
      })

      assert.are.same('lens', derived.mode)
      assert.are.same(200, derived.width)
      assert.are.same(50, derived.height)
      assert.are.same(2, derived.zindex)
    end)

    it('should not modify original context', function()
      context = LayoutContext({ mode = 'popup' })
      local derived = context:derive({ mode = 'lens' })

      assert.are.same('popup', context.mode)
      assert.are.same('lens', derived.mode)
    end)
  end)

  describe('get_props_for_component', function()
    it('should return mode, dimensions, and zindex', function()
      context = LayoutContext({
        mode = 'lens',
        width = 100,
        height = 50,
        zindex = 5,
      })

      local props = context:get_props_for_component()

      assert.are.same('lens', props.mode)
      assert.are.same(5, props.zindex)
      assert.is_not_nil(props.dimensions)
      assert.are.same(100, props.dimensions.width)
      assert.are.same(50, props.dimensions.height)
    end)
  end)

  describe('create_parent_bounds', function()
    before_each(function()
      vim.o.columns = 200
      vim.o.lines = 50
    end)

    it('should create viewport bounds for non-lens modes', function()
      context = LayoutContext({ mode = 'popup' })
      local bounds = context:create_parent_bounds()

      assert.are.same(0, bounds.row)
      assert.are.same(0, bounds.col)
      assert.are.same(200, bounds.width)
      assert.are.same(50, bounds.height)
    end)

    it('should create lens bounds for lens mode', function()
      -- Mock vim.fn.winline to return cursor at row 10
      vim.fn.winline = function()
        return 10
      end

      context = LayoutContext({
        mode = 'lens',
        height = 20,
      })

      local bounds = context:create_parent_bounds()

      assert.are.same(10, bounds.row) -- (winline - 1) + 1 = lens below cursor
      assert.are.same(0, bounds.col)
      assert.are.same(200, bounds.width)
      assert.is_not_nil(bounds.height)
    end)
  end)

  describe('create_lens_bounds', function()
    local LayoutBounds

    before_each(function()
      LayoutBounds = require('vgit.ui.layout.LayoutBounds')
      vim.o.columns = 200
      vim.o.lines = 50
      vim.fn.winline = function()
        return 10
      end
    end)

    it('should position lens below cursor', function()
      local viewport_bounds = LayoutBounds.from_viewport()
      context = LayoutContext({
        mode = 'lens',
        height = 20,
      })

      local lens_bounds = context:create_lens_bounds(viewport_bounds)

      assert.are.same(10, lens_bounds.row) -- (10 - 1) + 1 = lens below cursor
      assert.are.same(0, lens_bounds.col)
      assert.are.same(200, lens_bounds.width)
    end)

    it('should shift lens up if insufficient space below cursor', function()
      local viewport_bounds = LayoutBounds.from_viewport()
      vim.fn.winline = function()
        return 45
      end -- Near bottom

      context = LayoutContext({
        mode = 'lens',
        height = 20,
      })

      local lens_bounds = context:create_lens_bounds(viewport_bounds)

      -- Should shift up to fit
      assert.is_true(lens_bounds.row < 44)
      assert.is_true(lens_bounds.height <= 50)
    end)

    it('should limit height to viewport height', function()
      local viewport_bounds = LayoutBounds.from_viewport()
      vim.fn.winline = function()
        return 10
      end

      context = LayoutContext({
        mode = 'lens',
        height = 100, -- Larger than viewport
      })

      local lens_bounds = context:create_lens_bounds(viewport_bounds)

      assert.is_true(lens_bounds.height <= 50)
    end)
  end)
end)
