local async = {}

local function is_callable(fn)
  if type(fn) == 'function' then return true end
  if type(fn) ~= 'table' then return false end
  local mt = getmetatable(fn)
  return mt ~= nil and type(mt.__call) == 'function'
end

local function run(fn, callback)
  assert(is_callable(fn), 'type error :: expected func')

  local task = vim.async.run(fn)

  if task:completed() then
    local res = { task:pwait(0) }
    if not res[1] then error(res[2], 0) end
    if callback then callback(unpack(res, 2, res.n)) end
    return task
  end

  if callback then
    task:on_complete(function(err, ...)
      if err then error(err, 0) end
      callback(...)
    end)
  else
    task:on_complete(function(err)
      if err then error(err, 0) end
    end)
  end

  return task
end

async.wrap = function(func, argc)
  assert(is_callable(func), 'type error :: expected func, got ' .. type(func))
  assert(type(argc) == 'number', 'type error :: expected number, got ' .. type(argc))

  return function(...)
    if select('#', ...) == argc then return func(...) end

    return vim.async.await(argc, func, ...)
  end
end

async.run = run

async.void = function(func)
  return function(...)
    assert(is_callable(func), 'type error :: expected func')
    local args = { ... }
    local argc = select('#', ...)
    run(function()
      func(unpack(args, 1, argc))
    end)
    return nil
  end
end

async.all = function(funcs, opts)
  if #funcs == 0 then return {} end

  local max = opts and opts.max_concurrent or #funcs
  local semaphore = vim.async.semaphore(max)

  local tasks = {}
  for i, fn in ipairs(funcs) do
    tasks[i] = vim.async.run(function()
      return semaphore:with(function()
        local ok, result = pcall(fn)
        if ok then return result end
        return nil
      end)
    end)
  end

  local results = {}
  for i, task in ipairs(tasks) do
    local ok, result = vim.async.pawait(task)
    if ok then results[i] = result end
  end

  return results
end

return async
