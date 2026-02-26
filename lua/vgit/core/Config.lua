local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')

local Config = Object:extend()

function Config:constructor(state)
  assert(type(state) == 'nil' or type(state) == 'table', 'type error :: expected table or nil')

  return { data = type(state) == 'table' and state or {} }
end

function Config:get(key)
  assert(type(key) == 'string', 'type error :: expected string')
  local value = self.data[key]
  if value == nil then error(string.format('key "%s" does not exist', tostring(key))) end

  return value
end

function Config:set(key, value)
  if self.data[key] == nil then error(string.format('key "%s" does not exist', tostring(key))) end
  if type(self.data[key]) ~= type(value) then
    error(string.format('type error :: expected %s', type(self.data[key])))
  end

  self.data[key] = value

  return self
end

function Config:assign(config)
  if config == nil then return self.data end

  for key, value in pairs(config) do
    if self.data[key] ~= nil then
      if type(self.data[key]) == 'table' and type(value) == 'table' then
        if vim.islist(value) then
          self.data[key] = value
        else
          self.data[key] = utils.object.assign(self.data[key], value)
        end
      else
        self.data[key] = value
      end
    else
      console.debug.warning(string.format('Unknown config key "%s" will be ignored', key))
    end
  end

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
