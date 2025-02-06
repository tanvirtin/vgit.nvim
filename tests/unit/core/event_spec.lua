local event = require('vgit.core.event')
local Buffer = require('vgit.core.Buffer')

describe('event', function()
  describe('on', function()
    it('should create an autocmd for the specified event', function()
      local callback_called = false
      event.on('BufRead', function()
        callback_called = true
      end)
      vim.api.nvim_exec_autocmds('BufRead', { modeline = false })

      assert.is_true(callback_called)
    end)
  end)

  describe('buffer_on', function()
    it('should create an autocmd for the specified buffer event', function()
      local callback_called = false
      local buffer = Buffer(0)
      event.buffer_on(buffer, 'BufRead', function()
        callback_called = true
      end)
      vim.api.nvim_exec_autocmds('BufRead', { buffer = buffer.bufnr, modeline = false })

      assert.is_true(callback_called)
    end)
  end)

  describe('custom_on', function()
    it('should create a custom autocmd for the specified event', function()
      local callback_called = false

      event.custom_on('CustomEvent', function()
        callback_called = true
      end)
      vim.api.nvim_exec_autocmds('User', { pattern = 'CustomEvent', modeline = false })

      assert.is_true(callback_called)
    end)
  end)

  describe('emit', function()
    it('should emit a custom event and call the associated callbacks', function()
      local callback_called = false

      event.custom_on('CustomEvent', function()
        callback_called = true
      end)
      event.emit('CustomEvent', {})

      assert.is_true(callback_called)
    end)
  end)
end)
