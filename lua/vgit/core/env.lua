local assertion = require('vgit.core.assertion')

local state = {}

local env = {}

function env.set(key, value)
  assertion.assert_string(key).assert_types(
    value,
    { 'string', 'number', 'boolean' }
  )
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

return env
