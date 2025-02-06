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

function loop.debounce(fn, ms, opts)
  opts = opts or {}

  local prolong = opts.prolong ~= nil and opts.prolong or true

  local args, argc
  local cooldown = false
  local timer = vim.loop.new_timer()

  return function(...)
    args = { ... }
    argc = select('#', ...)

    if not cooldown then
      cooldown = true
      fn(...)
      timer:start(ms, 0, function()
        cooldown = false
      end)
      return
    end

    if not prolong then return end

    timer:stop()
    timer:start(ms, 0, function()
      cooldown = false
      fn(unpack(args, 1, argc))
    end)
  end
end

function loop.debounce_coroutine(fn, ms)
  return loop.debounce(loop.coroutine(fn), ms)
end

return loop
