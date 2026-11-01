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
    it('should return consistent dimensions', function()
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

  describe('restore_window_options', function()
    local win

    before_each(function()
      vim.cmd('enew!')
      vim.go.number = true
      win = vim.api.nvim_get_current_win()
      vim.api.nvim_set_option_value('number', false, { scope = 'local', win = win })
    end)

    after_each(function()
      vim.api.nvim_set_option_value('number', true, { scope = 'local', win = win })
    end)

    it('puts the captured options back on the same buffer', function()
      local ctx = LayoutContext({ mode = 'split' })

      vim.api.nvim_set_option_value('number', true, { scope = 'local', win = win })
      ctx:restore_window_options()

      eq(false, vim.api.nvim_get_option_value('number', { win = win }))
    end)

    it('leaves another buffer\'s own options alone', function()
      local ctx = LayoutContext({ mode = 'split' })
      local other = vim.api.nvim_create_buf(true, true)

      vim.api.nvim_win_set_buf(win, other)
      vim.api.nvim_set_option_value('number', true, { scope = 'local', win = win })
      ctx:restore_window_options()

      eq(true, vim.api.nvim_get_option_value('number', { win = win }))
    end)
  end)
end)
