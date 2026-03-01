local Object = {}

function Object:__index(key)
  local value = rawget(self, '$' .. key)
  if value ~= nil then return value end

  local class = getmetatable(self)

  return class[key]
end

function Object:__newindex(key, value)
  if rawget(self, '$' .. key) ~= nil then
    error(string.format("Property '%s' is read-only.", tostring(key)), 2)
  end

  rawset(self, key, value)
end

function Object:is(T)
  local mt = getmetatable(self)

  while mt do
    if mt == T then return true end
    mt = getmetatable(mt)
  end

  return false
end

function Object:extend()
  local cls = {}

  for k, v in pairs(self) do
    if k:find('__') == 1 then cls[k] = v end
  end

  cls.super = self

  return setmetatable(cls, self)
end

function Object:constructor(...)
  return {}
end

function Object:__call(...)
  local instance = self:constructor(...) or {}

  setmetatable(instance, self)

  return instance
end

return Object
