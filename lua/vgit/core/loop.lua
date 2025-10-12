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
  local closed = false

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
      -- Schedule to avoid fast event context issues
      vim.schedule(function()
        fn(unpack(args, 1, argc))
      end)
    end)
  end

  -- Store cleanup function in registry keyed by the debounced function
  debounced_registry[debounced] = function()
    if not closed and timer and not timer:is_closing() then
      timer:stop()
      timer:close()
      closed = true
      timer = nil
    end
  end

  return debounced
end

-- Close a debounced function's timer handle
function loop.close_debounced(debounced_fn)
  local close_fn = debounced_registry[debounced_fn]
  if close_fn then
    close_fn()
    debounced_registry[debounced_fn] = nil
  end
end

-- Close all debounced handlers in a table
function loop.close_debounced_handlers(handlers)
  if not handlers then return end
  for _, handler in pairs(handlers) do
    if type(handler) == 'function' then
      loop.close_debounced(handler)
    end
  end
end

function loop.debounce_coroutine(fn, ms)
  return loop.debounce(loop.coroutine(fn), ms)
end

return loop
