local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Config = Object:extend()

function Config:new(state)
  assert(
    type(state) == 'nil' or type(state) == 'table',
    'type error :: expected table or nil'
  )
  return setmetatable({ data = type(state) == 'table' and state or {} }, Config)
end

function Config:get(key)
  assert(type(key) == 'string', 'type error :: expected string')
  assert(self.data[key] ~= nil, string.format('key "%s" does not exist', key))
  return self.data[key]
end

function Config:set(key, value)
  assert(self.data[key] ~= nil, string.format('key "%s" does not exist', key))
  assert(
    type(self.data[key]) == type(value),
    string.format('type error :: expected %s', key)
  )
  self.data[key] = value
  return self
end

function Config:assign(config)
  self.data = utils.object.assign(self.data, config)
  return self.data
end

function Config:for_each(callback)
  for key, value in pairs(self.data) do
    callback(key, value)
  end
  return self
end

function Config:size()
  local count = 0
  for _, _ in pairs(self.data) do
    count = count + 1
  end
  return count
end

return Config
