local plenary_async = require('plenary.async.async')

local function run(fn)
  local finished = false
  local test_error = nil

  vim.schedule(function()
    plenary_async.run(function()
      local ok, err = pcall(fn)
      if not ok then
        test_error = err
      end
      finished = true
    end)
  end)

  vim.wait(30000, function() return finished end, 10)

  if test_error then error(test_error, 0) end
  if not finished then error('async test timed out after 30s', 0) end
end

return function(fns)
  local wrapped = {}
  if fns.it then
    wrapped.it = function(name, fn) fns.it(name, function() run(fn) end) end
  end
  if fns.before_each then
    wrapped.before_each = function(fn) fns.before_each(function() run(fn) end) end
  end
  if fns.after_each then
    wrapped.after_each = function(fn) fns.after_each(function() run(fn) end) end
  end
  return wrapped
end
