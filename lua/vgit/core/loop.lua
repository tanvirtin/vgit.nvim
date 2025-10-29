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

-- Registry to track debounced handlers and their cleanup functions
-- Uses weak keys so handlers can be garbage collected when no longer referenced
local debounced_registry = setmetatable({}, { __mode = 'k' })

function loop.debounce(fn, ms)
  local timer = vim.loop.new_timer()
  local closed = false

  local debounced = function(...)
    if closed then return end
    local argv = { ... }
    local argc = select('#', ...)

    timer:stop()
    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
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
