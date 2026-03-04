local spy = require('luassert.spy')
local renderer = require('vgit.core.renderer')

local eq = assert.are.same

describe('renderer:', function()
  before_each(function()
    renderer.reset()
  end)

  describe('register_module', function()
    it('should register the decoration provider', function()
      local s = spy.on(vim.api, 'nvim_set_decoration_provider')

      renderer.register_module()

      assert.is_true(renderer.registered)
      assert.spy(s).was.called()
      vim.api.nvim_set_decoration_provider:revert()
    end)

    it('should not register twice', function()
      local s = spy.on(vim.api, 'nvim_set_decoration_provider')

      renderer.register_module()
      renderer.register_module()

      assert.spy(s).was.called(1)
      vim.api.nvim_set_decoration_provider:revert()
    end)

    it('should create namespace', function()
      renderer.register_module()
      assert.is_not_nil(renderer.ns_id)
    end)

    it('should return renderer for chaining', function()
      local result = renderer.register_module()
      eq(renderer, result)
    end)
  end)

  describe('attach', function()
    it('should track the buffer by bufnr', function()
      local buffer = { bufnr = 42 }
      renderer.attach(buffer)

      eq(buffer, renderer.buffers[42])
    end)

    it('should be idempotent for same buffer', function()
      local buffer = { bufnr = 42 }
      renderer.attach(buffer)
      renderer.attach(buffer)

      eq(buffer, renderer.buffers[42])
    end)

    it('should track multiple buffers independently', function()
      local buf1 = { bufnr = 1 }
      local buf2 = { bufnr = 2 }

      renderer.attach(buf1)
      renderer.attach(buf2)

      eq(buf1, renderer.buffers[1])
      eq(buf2, renderer.buffers[2])
    end)

    it('should return renderer for chaining', function()
      local result = renderer.attach({ bufnr = 1 })
      eq(renderer, result)
    end)
  end)

  describe('detach', function()
    it('should remove the buffer from tracking', function()
      local buffer = { bufnr = 42 }
      renderer.attach(buffer)
      renderer.detach(buffer)

      assert.is_nil(renderer.buffers[42])
    end)

    it('should not affect other attached buffers', function()
      local buf1 = { bufnr = 1 }
      local buf2 = { bufnr = 2 }

      renderer.attach(buf1)
      renderer.attach(buf2)
      renderer.detach(buf1)

      assert.is_nil(renderer.buffers[1])
      eq(buf2, renderer.buffers[2])
    end)

    it('should return renderer for chaining', function()
      local result = renderer.detach({ bufnr = 1 })
      eq(renderer, result)
    end)
  end)

  describe('reset', function()
    it('should clear registered flag', function()
      renderer.registered = true
      renderer.reset()
      assert.is_false(renderer.registered)
    end)

    it('should clear all buffers', function()
      renderer.attach({ bufnr = 1 })
      renderer.attach({ bufnr = 2 })
      renderer.reset()

      eq({}, renderer.buffers)
    end)

    it('should clear ns_id', function()
      renderer.ns_id = 99
      renderer.reset()
      assert.is_nil(renderer.ns_id)
    end)
  end)
end)
