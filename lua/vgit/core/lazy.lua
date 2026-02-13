local module_cache = {}

local function lazy(mod_path)
  if module_cache[mod_path] then return module_cache[mod_path] end

  local proxy = {}
  local resolved = false

  local function resolve()
    if resolved then return end
    resolved = true
    local mod = require(mod_path)
    -- Copy metamethod keys so proxy works when used as a metatable
    -- (Lua resolves metamethods via rawget on the metatable)
    for k, v in pairs(mod) do
      if type(k) == 'string' and k:sub(1, 2) == '__' then rawset(proxy, k, v) end
    end
  end

  setmetatable(proxy, {
    __index = function(_, k)
      if not resolved then resolve() end
      return require(mod_path)[k]
    end,
    __newindex = function(_, k, v)
      if not resolved then resolve() end
      require(mod_path)[k] = v
    end,
    __call = function(_, ...)
      if not resolved then resolve() end
      local mod = require(mod_path)
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
