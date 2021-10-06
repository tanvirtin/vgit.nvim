local M = {}

M.throttle_leading = function(fn, ms)
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

M.debounce_trailing = function(fn, ms)
  local timer = vim.loop.new_timer()
  return function(...)
    local argv = { ... }
    local argc = select('#', ...)
    timer:start(ms, 0, function()
      fn(unpack(argv, 1, argc))
    end)
  end
end

return M
