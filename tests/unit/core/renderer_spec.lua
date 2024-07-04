local spy = require('luassert.spy')
local renderer = require('vgit.core.renderer')

describe('renderer', function()
  local buffer = { bufnr = 1, on_render = function() end }

  before_each(function()
    renderer.buffers = {}
    renderer.registered = false
  end)

  describe('register_module', function()
    it('should register the module if not already registered', function()
      local spy_vim_set_decoration_provider = spy.on(vim.api, 'nvim_set_decoration_provider')

      renderer.register_module()

      assert.is_true(renderer.registered)
      assert.spy(spy_vim_set_decoration_provider).was.called()
    end)

    it('should not register the module if already registered', function()
      local spy_vim_set_decoration_provider = spy.on(vim.api, 'nvim_set_decoration_provider')

      renderer.registered = true
      renderer.register_module()

      assert.is_true(renderer.registered)
      assert.spy(spy_vim_set_decoration_provider).was_not.called()
    end)
  end)

  describe('attach', function()
    it('should attach a buffer', function()
      renderer.attach(buffer)
      assert.is_not_nil(renderer.buffers[buffer.bufnr])
    end)
  end)

  describe('detach', function()
    it('should detach a buffer', function()
      renderer.attach(buffer)
      renderer.detach(buffer)
      assert.is_nil(renderer.buffers[buffer.bufnr])
    end)
  end)
end)
