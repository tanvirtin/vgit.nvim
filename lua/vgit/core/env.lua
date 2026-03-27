local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local assertion = lazy('vgit.core.assertion')

local is_registered = false

local state = {}

local env = {}

function env._reset()
  is_registered = false
  state = {}
end

function env.register_module()
  if is_registered then return end
  is_registered = true

  state = utils.object.assign({}, vim.fn.environ())
  state['LC_ALL'] = 'C'
  state['LANGUAGE'] = 'C'
end

function env.set(key, value)
  assertion.assert_string(key).assert_types(value, { 'string', 'number', 'boolean' })
  state[key] = value
  return env
end

function env.unset(key)
  assertion.assert_string(key)
  assertion.assert(state[key], 'error :: no value set for given key')
  state[key] = nil
  return env
end

function env.get(key)
  assertion.assert_string(key)
  return state[key]
end

function env.get_all()
  local result = {}
  for k, v in pairs(state) do
    result[#result + 1] = string.format('%s=%s', k, v)
  end

  return result
end

return env
