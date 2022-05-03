local Object = require('vgit.core.Object')

local Set = Object:extend()

function Set:constructor(list)
  local set = {}

  for i = 1, #list do
    set[list[i]] = true
  end

  return {
    set = set,
  }
end

function Set:has(key)
  return self.set[key] ~= nil
end

function Set:add(key)
  self.set[key] = true

  return self
end

function Set:delete(key)
  self.set[key] = nil

  return self
end

function Set:for_each(callback)
  local count = 1

  for key in pairs(self.set) do
    local result = callback(key, count)

    if result == false then
      break
    end
  end

  return self
end

function Set:to_list()
  local list = {}

  for key in pairs(self.set) do
    list[#list + 1] = key
  end

  return list
end

return Set
