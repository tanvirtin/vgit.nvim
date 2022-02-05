local scheduler = require('plenary.async.util').scheduler
local async = require('plenary.async.async')

local loop = {}

loop.async = async.void

loop.promisify = async.wrap

function loop.await_fast_event(times)
  for _ = 1, times or 1 do
    scheduler()
  end

  return loop
end

-- Dynamic debounce, apply some breaks if we go too fast.
function loop.brakecheck(fn, opts)
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

function loop.debounce(fn, ms)
  local timer = vim.loop.new_timer()

  return function(...)
    local argv = { ... }
    local argc = select('#', ...)

    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
    end)
  end
end

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
