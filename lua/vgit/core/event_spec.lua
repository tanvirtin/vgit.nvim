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

  describe('debounce', function()
    it('should execute first call immediately', function()
      local call_count = 0
      local debounced, cleanup = event.debounce(function()
        call_count = call_count + 1
      end, 100)

      debounced()
      assert.are.equal(1, call_count)
      cleanup()
    end)

    it('should defer second call within cooldown period', function()
      local call_count = 0
      local debounced, cleanup = event.debounce(function()
        call_count = call_count + 1
      end, 50)

      debounced()
      assert.are.equal(1, call_count)

      -- Second call within cooldown should NOT execute immediately
      debounced()
      assert.are.equal(1, call_count)

      -- Wait for debounce timer + schedule to fire
      vim.wait(200, function() return call_count >= 2 end, 10)
      assert.are.equal(2, call_count)

      cleanup()
    end)

    it('should forward arguments correctly', function()
      local received_args = {}
      local debounced, cleanup = event.debounce(function(a, b)
        received_args = { a, b }
      end, 100)

      debounced('hello', 42)
      assert.are.same({ 'hello', 42 }, received_args)
      cleanup()
    end)

    it('cleanup should stop timer and reset state', function()
      local call_count = 0
      local debounced, cleanup = event.debounce(function()
        call_count = call_count + 1
      end, 50)

      debounced()
      assert.are.equal(1, call_count)

      -- Second call schedules a deferred execution
      debounced()
      assert.are.equal(1, call_count)

      -- Cleanup before timer fires
      cleanup()

      -- Wait past the debounce period — deferred call should NOT fire
      vim.wait(150, function() return false end, 10)
      assert.are.equal(1, call_count)
    end)
  end)

  describe('debounce_async', function()
    it('should return debounced function and cleanup function', function()
      local debounced, cleanup = event.debounce_async(function() end, 100)

      assert.is_function(debounced)
      assert.is_function(cleanup)
      cleanup()
    end)
  end)

  describe('custom_on cleanup', function()
    it('should remove autocmd when cleanup is called', function()
      local call_count = 0
      local cleanup = event.custom_on('TestCleanupEvent', function()
        call_count = call_count + 1
      end)

      event.emit('TestCleanupEvent', {})
      assert.are.equal(1, call_count)

      cleanup()

      -- Emitting again should not increment since autocmd was removed
      pcall(event.emit, 'TestCleanupEvent', {})
      assert.are.equal(1, call_count)
    end)

    it('should be safe to call cleanup twice', function()
      local cleanup = event.custom_on('TestDoubleCleanup', function() end)

      cleanup()

      assert.has_no.errors(function()
        cleanup()
      end)
    end)
  end)

  describe('disposable_on', function()
    it('should remove augroup when cleanup is called', function()
      local call_count = 0
      local cleanup = event.disposable_on('BufRead', function()
        call_count = call_count + 1
      end)

      vim.api.nvim_exec_autocmds('BufRead', { modeline = false })
      assert.are.equal(1, call_count)

      cleanup()

      -- After cleanup, the autocmd should be removed
      vim.api.nvim_exec_autocmds('BufRead', { modeline = false })
      assert.are.equal(1, call_count)
    end)

    it('should be safe to call cleanup twice', function()
      local cleanup = event.disposable_on('BufRead', function() end)

      cleanup()

      assert.has_no.errors(function()
        cleanup()
      end)
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
