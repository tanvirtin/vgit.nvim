local list = require('vgit.core.utils.list')

local assertion = {}

local function inspect(value)
  if vim and vim.inspect then return vim.inspect(value) end
  if type(value) ~= 'table' then return tostring(value) end

  local parts = {}

  for i = 1, #value do
    parts[#parts + 1] = inspect(value[i])
  end

  return '{' .. table.concat(parts, ', ') .. '}'
end

function assertion.assert(cond, msg)
  if type(cond) == 'function' then cond = cond() end
  if not cond then error(debug.traceback(msg)) end

  return assertion
end

function assertion.assert_type(value, t)
  assertion.assert(type(value) == t, string.format('type error :: expected %s', t))

  return assertion
end

function assertion.assert_types(value, types)
  assertion.assert_list(types)
  local passed = false

  for i = 1, #types do
    local t = types[i]
    if type(value) == t then passed = true end
  end

  assertion.assert(passed, string.format('type error :: expected %s', inspect(types)))

  return assertion
end

function assertion.assert_number(value)
  assertion.assert_type(value, 'number')

  return assertion
end

function assertion.assert_string(value)
  assertion.assert_type(value, 'string')

  return assertion
end

function assertion.assert_function(value)
  assertion.assert_type(value, 'function')

  return assertion
end

function assertion.assert_boolean(value)
  assertion.assert_type(value, 'boolean')

  return assertion
end

function assertion.assert_nil(value)
  assertion.assert_type(value, 'nil')

  return assertion
end

function assertion.assert_table(value)
  assertion.assert_type(value, 'table')

  return assertion
end

function assertion.assert_list(value)
  assertion.assert(list.is_list(value), 'type error :: expected list')

  return assertion
end

return assertion
