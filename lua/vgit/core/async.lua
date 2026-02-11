local co = coroutine

local M = {}

local function is_callable(fn)
  return type(fn) == 'function'
    or (type(fn) == 'table' and type(getmetatable(fn).__call) == 'function')
end

local function rotate(nargs, ...)
  if not nargs or nargs < 1 then return end
  local args = { ... }
  local first = args[1]
  for i = 1, nargs - 1 do
    args[i] = args[i + 1]
  end
  args[nargs] = first
  return unpack(args, 1, nargs)
end

local function callback_or_next(step, thread, callback, ...)
  local stat = select(1, ...)

  if not stat then
    error(
      string.format(
        'The coroutine failed with this message: %s',
        tostring(select(2, ...))
      )
    )
  end

  if co.status(thread) == 'dead' then
    if callback then
      callback(select(2, ...))
    end
  else
    local returned_function = select(2, ...)
    local nargs = select(3, ...)

    assert(is_callable(returned_function), 'type error :: expected func')
    returned_function(rotate(nargs, step, select(4, ...)))
  end
end

local function execute(async_function, callback, ...)
  assert(is_callable(async_function), 'type error :: expected func')

  local thread = co.create(async_function)

  local step
  step = function(...)
    callback_or_next(step, thread, callback, co.resume(thread, ...))
  end

  step(...)
end

M.wrap = function(func, argc)
  assert(is_callable(func), 'type error :: expected func, got ' .. type(func))
  assert(
    type(argc) == 'number',
    'type error :: expected number, got ' .. type(argc)
  )

  return function(...)
    if select('#', ...) == argc then
      return func(...)
    else
      return co.yield(func, argc, ...)
    end
  end
end

M.run = function(async_function, callback)
  execute(async_function, callback)
end

M.void = function(func)
  return function(...)
    execute(func, nil, ...)
  end
end

return M
