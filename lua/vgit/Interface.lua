local Object = require('plenary.class')
local assert = require('vgit.assertion').assert

local Interface = Object:extend()

function Interface:new(state)
  assert(
    type(state) == 'nil' or type(state) == 'table',
    'type error :: expected table or nil'
  )
  return setmetatable(
    { data = type(state) == 'table' and state or {} },
    Interface
  )
end

function Interface:get(key)
  assert(type(key) == 'string', 'type error :: expected string')
  assert(self.data[key] ~= nil, string.format('key "%s" does not exist', key))
  return self.data[key]
end

function Interface:set(key, value)
  assert(self.data[key] ~= nil, string.format('key "%s" does not exist', key))
  assert(
    type(self.data[key]) == type(value),
    string.format('type error :: expected %s', key)
  )
  self.data[key] = value
end

function Interface:assign(config)
  if not config then
    return self
  end
  local function assign(state_segment, config_segment)
    local state_segment_type = type(state_segment)
    local config_segment_type = type(config_segment)
    assert(state_segment_type == config_segment_type, 'invalid config')
    if
      config_segment_type == 'table' and not vim.tbl_islist(config_segment)
    then
      for key, state_value in pairs(state_segment) do
        local config_value = config_segment[key]
        if config_value ~= nil then
          local state_value_type = type(state_value)
          local config_value_type = type(config_value)
          if
            config_value_type == 'table' and not vim.tbl_islist(config_value)
          then
            assign(state_segment[key], config_segment[key])
          else
            assert(state_value_type == config_value_type, 'invalid config')
            state_segment[key] = config_value
          end
        end
      end
    end
  end
  assign(self.data, config)
  return self
end

return Interface
