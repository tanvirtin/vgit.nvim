local scheduler = require('plenary.async.util').scheduler
local async = require('plenary.async.async')

local loop = {}

-- Dynamic debounce, apply some breaks if we go too fast.
loop.brakecheck = function(fn, opts)
  opts = opts or {}
  local timer = vim.loop.new_timer()
  local initial_ms = opts.initial_ms or 0
  local step_ms = opts.step_ms or 5
  local cutoff_ms = opts.cutoff_ms or 100
  local ms = initial_ms
  return function(...)
    local argv = { ... }
    local argc = select('#', ...)
    if ms >= cutoff_ms then
      ms = initial_ms
    end
    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
    end)
    ms = ms + step_ms
  end
end

loop.throttle = function(fn, ms)
  local timer = vim.loop.new_timer()
  local running = false
  return function(...)
    if running then
      return
    end
    timer:start(ms, 0, function()
      running = false
    end)
    running = true
    fn(...)
  end
end

loop.debounce = function(fn, ms)
  local timer = vim.loop.new_timer()
  return function(...)
    local argv = { ... }
    local argc = select('#', ...)
    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
    end)
  end
end

loop.watch = function(filepath, callback)
  local watcher = vim.loop.new_fs_event()
  vim.loop.fs_event_start(watcher, filepath, {
    watch_entry = false,
    stat = false,
    recursive = false,
  }, callback)
  return watcher
end

loop.unwatch = function(watcher)
  vim.loop.fs_event_stop(watcher)
end

loop.async = async.void

loop.promisify = async.wrap

loop.await_fast_event = scheduler

return loop
