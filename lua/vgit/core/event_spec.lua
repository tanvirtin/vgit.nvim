local event = require('vgit.core.event')
local Buffer = require('vgit.core.Buffer')

local eq = assert.are.same

describe('event:', function()
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

  describe('VGitDirChanged', function()
    it('should be emittable and receivable via custom_on', function()
      local received = false
      event.custom_on('VGitDirChanged', function()
        received = true
      end)
      event.emit('VGitDirChanged', {})
      assert.is_true(received)
    end)

    it('should emit VGitDirChanged for global DirChanged scope', function()
      local count = 0
      event.custom_on('VGitDirChanged', function()
        count = count + 1
      end)
      event.on({ 'DirChanged' }, function(args)
        if args.match ~= 'global' then return end
        event.emit('VGitDirChanged', {})
      end)
      vim.api.nvim_exec_autocmds('DirChanged', { pattern = 'global', modeline = false })
      eq(count, 1)
    end)

    it('should not emit VGitDirChanged for local DirChanged scope', function()
      local count = 0
      event.custom_on('VGitDirChanged', function()
        count = count + 1
      end)
      event.on({ 'DirChanged' }, function(args)
        if args.match ~= 'global' then return end
        event.emit('VGitDirChanged', {})
      end)
      vim.api.nvim_exec_autocmds('DirChanged', { pattern = 'local', modeline = false })
      eq(count, 0)
    end)

    it('should not emit VGitDirChanged for tab DirChanged scope', function()
      local count = 0
      event.custom_on('VGitDirChanged', function()
        count = count + 1
      end)
      event.on({ 'DirChanged' }, function(args)
        if args.match ~= 'global' then return end
        event.emit('VGitDirChanged', {})
      end)
      vim.api.nvim_exec_autocmds('DirChanged', { pattern = 'tab', modeline = false })
      eq(count, 0)
    end)
  end)
end)
