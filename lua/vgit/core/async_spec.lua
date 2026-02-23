local async = require('vgit.core.async')

local eq = assert.are.same

describe('async:', function()
  describe('wrap', function()
    it('should return a function', function()
      local wrapped = async.wrap(function(cb)
        cb()
      end, 1)

      eq('function', type(wrapped))
    end)

    it('should error when func is not callable', function()
      assert.has_error(function()
        async.wrap('not a function', 1)
      end)
    end)

    it('should error when argc is not a number', function()
      assert.has_error(function()
        async.wrap(function() end, 'not a number')
      end)
    end)

    it('should call func directly when called with exactly argc args', function()
      local called_with = nil
      local fn = function(a, cb)
        called_with = a
        cb('result')
      end
      local wrapped = async.wrap(fn, 2)

      wrapped('hello', function() end)

      eq('hello', called_with)
    end)

    it('should yield when called with fewer than argc args inside a coroutine', function()
      local result = nil
      local fn = function(cb)
        cb('done')
      end
      local wrapped = async.wrap(fn, 1)

      async.run(function()
        result = wrapped()
      end)

      eq('done', result)
    end)

    it('should pass yielded result back to the coroutine', function()
      local result = nil
      local fn = function(a, b, cb)
        cb(a + b)
      end
      local wrapped = async.wrap(fn, 3)

      async.run(function()
        result = wrapped(10, 20)
      end)

      eq(30, result)
    end)

    it('should support multiple return values through callback', function()
      local r1, r2 = nil, nil
      local fn = function(cb)
        cb('first', 'second')
      end
      local wrapped = async.wrap(fn, 1)

      async.run(function()
        r1, r2 = wrapped()
      end)

      eq('first', r1)
      eq('second', r2)
    end)

    it('should support wrapping vim.schedule', function()
      local scheduled = false
      local await = async.wrap(vim.schedule, 1)

      async.run(function()
        await()
        scheduled = true
      end)

      vim.wait(1000, function()
        return scheduled
      end, 10)

      assert.is_true(scheduled)
    end)
  end)

  describe('void', function()
    it('should return a function', function()
      local voided = async.void(function() end)

      eq('function', type(voided))
    end)

    it('should error when func is not callable', function()
      assert.has_error(function()
        async.void('not a function')()
      end)
    end)

    it('should execute the function', function()
      local called = false
      local voided = async.void(function()
        called = true
      end)

      voided()

      assert.is_true(called)
    end)

    it('should pass arguments to the function', function()
      local captured_args = {}
      local voided = async.void(function(a, b, c)
        captured_args = { a, b, c }
      end)

      voided('x', 'y', 'z')

      eq({ 'x', 'y', 'z' }, captured_args)
    end)

    it('should allow wrapped async calls inside', function()
      local result = nil
      local fn = function(val, cb)
        cb(val * 2)
      end
      local doubled = async.wrap(fn, 2)

      local voided = async.void(function()
        result = doubled(21)
      end)

      voided()

      eq(42, result)
    end)

    it('should not return a value', function()
      local voided = async.void(function()
        return 'should be discarded'
      end)

      local ret = voided()

      assert.is_nil(ret)
    end)
  end)

  describe('run', function()
    it('should execute an async function', function()
      local executed = false

      async.run(function()
        executed = true
      end)

      assert.is_true(executed)
    end)

    it('should call callback when the async function completes', function()
      local cb_result = nil

      async.run(function()
        return 'hello'
      end, function(val)
        cb_result = val
      end)

      eq('hello', cb_result)
    end)

    it('should pass multiple return values to callback', function()
      local results = {}

      async.run(function()
        return 'a', 'b', 'c'
      end, function(...)
        results = { ... }
      end)

      eq({ 'a', 'b', 'c' }, results)
    end)

    it('should work without a callback', function()
      assert.has_no_error(function()
        async.run(function()
          return 'no callback'
        end)
      end)
    end)

    it('should propagate errors from the coroutine', function()
      assert.has_error(function()
        async.run(function()
          error('test error')
        end)
      end)
    end)

    it('should work with wrapped async operations', function()
      local result = nil
      local fn = function(x, cb)
        cb(x + 1)
      end
      local increment = async.wrap(fn, 2)

      async.run(function()
        result = increment(5)
      end)

      eq(6, result)
    end)

    it('should support sequential wrapped calls', function()
      local result = nil
      local fn = function(x, cb)
        cb(x * 2)
      end
      local double = async.wrap(fn, 2)

      async.run(function()
        local a = double(3)
        local b = double(a)
        result = double(b)
      end)

      eq(24, result)
    end)

    it('should support mixed sync and async operations', function()
      local results = {}
      local async_add = async.wrap(function(a, b, cb)
        cb(a + b)
      end, 3)

      async.run(function()
        results[#results + 1] = 1
        results[#results + 1] = async_add(2, 3)
        results[#results + 1] = 6
        results[#results + 1] = async_add(4, 5)
      end)

      eq({ 1, 5, 6, 9 }, results)
    end)
  end)

  describe('all', function()
    it('should return empty table for empty funcs', function()
      local result = nil

      async.run(function()
        result = async.all({})
      end)

      eq({}, result)
    end)

    it('should run a single function and return its result', function()
      local result = nil

      async.run(function()
        result = async.all({
          function()
            return 42
          end,
        })
      end)

      eq({ 42 }, result)
    end)

    it('should run multiple functions and collect results in order', function()
      local result = nil

      async.run(function()
        result = async.all({
          function()
            return 'a'
          end,
          function()
            return 'b'
          end,
          function()
            return 'c'
          end,
        })
      end)

      eq({ 'a', 'b', 'c' }, result)
    end)

    it('should handle nil results from functions', function()
      local result = nil

      async.run(function()
        result = async.all({
          function()
            return 'first'
          end,
          function()
            return nil
          end,
          function()
            return 'third'
          end,
        })
      end)

      eq('first', result[1])
      assert.is_nil(result[2])
      eq('third', result[3])
    end)

    it('should work with async-wrapped functions', function()
      local result = nil
      local double = async.wrap(function(x, cb)
        cb(x * 2)
      end, 2)

      async.run(function()
        result = async.all({
          function()
            return double(5)
          end,
          function()
            return double(10)
          end,
          function()
            return double(15)
          end,
        })
      end)

      eq({ 10, 20, 30 }, result)
    end)

    it('should work with vim.schedule-based async functions', function()
      local result = nil
      local async_compute = async.wrap(function(val, cb)
        vim.schedule(function()
          cb(val * 3)
        end)
      end, 2)

      async.run(function()
        result = async.all({
          function()
            return async_compute(1)
          end,
          function()
            return async_compute(2)
          end,
          function()
            return async_compute(3)
          end,
        })
      end)

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq({ 3, 6, 9 }, result)
    end)

    it('should preserve result ordering regardless of completion order', function()
      local result = nil
      -- Simulate different completion times using vim.defer_fn
      local delayed = function(val, delay_ms)
        return async.wrap(function(cb)
          vim.defer_fn(function()
            cb(val)
          end, delay_ms)
        end, 1)
      end

      async.run(function()
        result = async.all({
          function()
            return delayed('slow', 30)()
          end,
          function()
            return delayed('fast', 5)()
          end,
          function()
            return delayed('medium', 15)()
          end,
        })
      end)

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq({ 'slow', 'fast', 'medium' }, result)
    end)

    it('should handle errors in functions without hanging', function()
      local result = nil

      async.run(function()
        result = async.all({
          function()
            return 'ok'
          end,
          function()
            error('boom')
          end,
          function()
            return 'also ok'
          end,
        })
      end)

      eq('ok', result[1])
      assert.is_nil(result[2])
      eq('also ok', result[3])
    end)

    it('should handle errors in async functions without hanging', function()
      local result = nil
      local async_op = async.wrap(function(val, cb)
        vim.schedule(function()
          cb(val)
        end)
      end, 2)

      async.run(function()
        result = async.all({
          function()
            return async_op('first')
          end,
          function()
            async_op('before error')
            error('async boom')
          end,
          function()
            return async_op('third')
          end,
        })
      end)

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq('first', result[1])
      assert.is_nil(result[2])
      eq('third', result[3])
    end)

    it('should respect max_concurrent option', function()
      local peak_concurrent = 0
      local current_concurrent = 0
      local result = nil

      local async_op = async.wrap(function(val, cb)
        current_concurrent = current_concurrent + 1
        if current_concurrent > peak_concurrent then peak_concurrent = current_concurrent end
        vim.schedule(function()
          current_concurrent = current_concurrent - 1
          cb(val)
        end)
      end, 2)

      async.run(function()
        result = async.all({
          function()
            return async_op(1)
          end,
          function()
            return async_op(2)
          end,
          function()
            return async_op(3)
          end,
          function()
            return async_op(4)
          end,
          function()
            return async_op(5)
          end,
        }, { max_concurrent = 2 })
      end)

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq({ 1, 2, 3, 4, 5 }, result)
      assert.is_true(peak_concurrent <= 2)
    end)

    it('should process all items even when max_concurrent is smaller than total', function()
      local result = nil

      async.run(function()
        result = async.all({
          function()
            return 'a'
          end,
          function()
            return 'b'
          end,
          function()
            return 'c'
          end,
          function()
            return 'd'
          end,
          function()
            return 'e'
          end,
        }, { max_concurrent = 2 })
      end)

      eq({ 'a', 'b', 'c', 'd', 'e' }, result)
    end)
  end)

  describe('integration', function()
    it('should support void calling wrapped functions that use vim.schedule', function()
      local result = nil
      local await = async.wrap(vim.schedule, 1)

      local voided = async.void(function()
        await()
        result = 'scheduled'
      end)

      voided()

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq('scheduled', result)
    end)

    it('should support chaining multiple async-wrapped calls with vim.schedule', function()
      local result = nil
      local await = async.wrap(vim.schedule, 1)
      local async_compute = async.wrap(function(val, cb)
        vim.schedule(function()
          cb(val * 10)
        end)
      end, 2)

      async.run(function()
        local a = async_compute(5)
        await()
        result = a
      end)

      vim.wait(1000, function()
        return result ~= nil
      end, 10)

      eq(50, result)
    end)

    it('should support callable tables', function()
      local callable = setmetatable({}, {
        __call = function(_, x)
          return x * 3
        end,
      })

      local result = nil

      async.run(function()
        result = callable(7)
      end)

      eq(21, result)
    end)

    it('should support wrapping a function that takes no additional args besides callback', function()
      local result = nil
      local get_value = async.wrap(function(cb)
        cb(42)
      end, 1)

      async.run(function()
        result = get_value()
      end)

      eq(42, result)
    end)

    it('should support wrapping a function with many args', function()
      local result = nil
      local sum = async.wrap(function(a, b, c, d, cb)
        cb(a + b + c + d)
      end, 5)

      async.run(function()
        result = sum(1, 2, 3, 4)
      end)

      eq(10, result)
    end)
  end)
end)
