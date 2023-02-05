local loop = {}

-- Given a function with a callback and the total number of arguments,
-- creates a closure which passes this data by yielding it in the coroutine
-- where this closure will be invoked.
-- @param fn the function with the callback.
-- @param argc the number of arguments of the function with the callback.
-- @returns a closure which yields the function, the args and additional
--          arguments which are passed as results from previous similar
--          coroutine yields.
function loop.suspend(fn, argc)
  return function(...) return coroutine.yield(fn, argc, ...) end
end

-- Given a function that contains computation to be ran as a coroutine,
-- recursively yields all closures created using loop.suspend within it.
-- The function with the callback is retrieved from the yield invoked by
-- resuming the coroutine. This function is then called with the callback
-- being resume_context to yield any remaining functions with callbacks.
-- @param fn the function that will be ran as a coroutine.
function loop.coroutine(fn)
  return function(...)
    local thread = coroutine.create(fn)

    local function resume_coroutine(...)
      local result = { coroutine.resume(thread, ...) }
      local ok, fn_with_callback, argc = unpack(result)

      if not ok then
        return error(string.format('coroutine failed :: %s\n%s', fn, debug.traceback(thread)))
      end

      if coroutine.status(thread) == 'dead' then
        return
      end

      local args = { select(4, unpack(result)) }
      args[argc] = resume_coroutine

      fn_with_callback(unpack(args, 1, argc))
    end

    resume_coroutine(...)
  end
end

loop.suspend_textlock = loop.suspend(vim.schedule, 1)

function loop.free_textlock(times)
  for _ = 1, times or 1 do
    loop.suspend_textlock()
  end

  return loop
end

function loop.debounce(fn, ms)
  local timer = vim.loop.new_timer()

  return function(...)
    local argv = { ... }
    local argc = select('#', ...)

    timer:start(ms, 0, function() fn(unpack(argv, 1, argc)) end)
  end
end

function loop.debounce_coroutine(fn, ms) return loop.debounce(loop.coroutine(fn), ms) end

return loop
