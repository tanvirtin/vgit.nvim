local loop = {}

loop.main_coroutine = coroutine.running()

function loop.async(func)
  return function(...)
    if coroutine.running() ~= loop.main_coroutine then
      return func(...)
    end

    local co = coroutine.create(func)

    local function step(...)
      local ret = { coroutine.resume(co, ...) }
      local stat, fn, nargs = unpack(ret)

      if not stat then
        error(string.format('coroutine failed :: %s\n%s', fn, debug.traceback(co)))
      end

      if coroutine.status(co) == 'dead' then
        return
      end

      local args = { select(4, unpack(ret)) }
      args[nargs] = step

      fn(unpack(args, 1, nargs))
    end

    step(...)
  end
end

function loop.promisify(func, argc)
  return function(...)
    if coroutine.running() == loop.main_coroutine then
      return func(...)
    end

    return coroutine.yield(func, argc, ...)
  end
end

loop.scheduler = loop.promisify(vim.schedule, 1)

function loop.await(times)
  for _ = 1, times or 1 do
    loop.scheduler()
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

function loop.debounced_async(fn, ms) return loop.debounce(loop.async(fn), ms) end

function loop.watch(filepath, callback)
  local watcher = vim.loop.new_fs_event()

  vim.loop.fs_event_start(watcher, filepath, {
    watch_entry = false,
    stat = false,
    recursive = false,
  }, callback)

  return watcher
end

function loop.unwatch(watcher)
  vim.loop.fs_event_stop(watcher)

  return loop
end

return loop
