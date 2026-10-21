local module_cache = {}

local loaded = package.loaded

local function lazy(mod_path)
  if module_cache[mod_path] then return module_cache[mod_path] end

  local proxy = {}
  local resolved = false

  local function module()
    return loaded[mod_path] or require(mod_path)
  end

  local function resolve()
    if resolved then return end
    resolved = true
    local mod = require(mod_path)
    for k, v in pairs(mod) do
      if type(k) == 'string' and k:sub(1, 2) == '__' then rawset(proxy, k, v) end
    end
  end

  setmetatable(proxy, {
    __index = function(_, k)
      if not resolved then resolve() end
      return module()[k]
    end,
    __newindex = function(_, k, v)
      if not resolved then resolve() end
      module()[k] = v
    end,
    __call = function(_, ...)
      if not resolved then resolve() end
      local mod = module()
      local mt = getmetatable(mod)
      if mt then
        local call_fn = rawget(mt, '__call')
        if call_fn then return call_fn(mod, ...) end
      end
    end,
  })

  module_cache[mod_path] = proxy

  return proxy
end

return lazy
