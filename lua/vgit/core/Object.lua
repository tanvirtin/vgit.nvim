local Object = {}

Object.__index = Object

function Object:constructor() return {} end

function Object:extend()
  local cls = {}

  for k, v in pairs(self) do
    if k:find('__') == 1 then
      cls[k] = v
    end
  end

  cls.__index = cls
  cls.super = self

  return setmetatable(cls, self)
end

function Object:is(T)
  local mt = getmetatable(self)

  while mt do
    if mt == T then
      return true
    end
    mt = getmetatable(mt)
  end

  return false
end

function Object:__call(...) return setmetatable(self:constructor(...) or self, self) end

return Object
