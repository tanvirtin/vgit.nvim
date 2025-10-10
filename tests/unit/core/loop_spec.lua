local loop = require('vgit.core.loop')

local eq = assert.are.same

describe('loop:', function()
  describe('free_textlock', function()
    it('should call suspend_textlock once by default', function()
      local call_count = 0
      local original = loop.suspend_textlock

      loop.suspend_textlock = function()
        call_count = call_count + 1
      end

      loop.free_textlock()

      loop.suspend_textlock = original
      eq(call_count, 1)
    end)

    it('should call suspend_textlock N times', function()
      local call_count = 0
      local original = loop.suspend_textlock

      loop.suspend_textlock = function()
        call_count = call_count + 1
      end

      loop.free_textlock(5)

      loop.suspend_textlock = original
      eq(call_count, 5)
    end)

    it('should return loop for chaining', function()
      local original = loop.suspend_textlock
      loop.suspend_textlock = function() end

      local result = loop.free_textlock(1)

      loop.suspend_textlock = original
      eq(result, loop)
    end)
  end)

  describe('debounce', function()
    it('should execute function immediately on first call', function()
      local executed = false
      local debounced = loop.debounce(function()
        executed = true
      end, 100)

      debounced()
      assert.is_true(executed)
    end)

    it('should pass single argument to wrapped function', function()
      local captured = nil
      local debounced = loop.debounce(function(arg)
        captured = arg
      end, 100)

      debounced('test_value')
      eq(captured, 'test_value')
    end)

    it('should pass multiple arguments to wrapped function', function()
      local captured_args = {}
      local debounced = loop.debounce(function(a, b, c)
        captured_args = { a, b, c }
      end, 100)

      debounced('arg1', 'arg2', 'arg3')
      eq(captured_args, { 'arg1', 'arg2', 'arg3' })
    end)
  end)

  describe('debounce_coroutine', function()
    it('should call loop.debounce with loop.coroutine wrapped function', function()
      local executed = false
      local test_fn = function()
        executed = true
      end

      local debounced_coro = loop.debounce_coroutine(test_fn, 100)
      debounced_coro()

      assert.is_true(executed)
    end)
  end)

  describe('suspend', function()
    it('should reference async.wrap from plenary', function()
      local async = require('plenary.async.async')
      eq(loop.suspend, async.wrap)
    end)
  end)

  describe('coroutine', function()
    it('should reference async.void from plenary', function()
      local async = require('plenary.async.async')
      eq(loop.coroutine, async.void)
    end)
  end)
end)
