local async = require('plenary.async.async')

local loop = {}

loop.suspend = async.wrap

loop.coroutine = async.void

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

    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
    end)
  end
end

function loop.debounce_coroutine(fn, ms)
  return loop.debounce(loop.coroutine(fn), ms)
end

return loop
