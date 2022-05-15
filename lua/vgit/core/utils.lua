local assertion = require('vgit.core.assertion')

-- Standard utility functions used throughout the app.

local utils = {
  object = {},
  list = {},
  time = {},
  math = {},
  str = {},
}

function utils.time.age(current_time)
  assertion.assert(current_time)
  local time = os.difftime(os.time(), current_time)
  local time_divisions = {
    { 1, 'years' },
    { 12, 'months' },
    { 30, 'days' },
    { 24, 'hours' },
    { 60, 'minutes' },
    { 60, 'seconds' },
  }

  for i = 1, #time_divisions do
    time = time / time_divisions[i][1]
  end

  local counter = 1
  local time_division = time_divisions[counter]
  local time_boundary = time_division[1]
  local time_postfix = time_division[2]

  while time < 1 and counter <= #time_divisions do
    time_division = time_divisions[counter]
    time_boundary = time_division[1]
    time_postfix = time_division[2]
    time = time * time_boundary
    counter = counter + 1
  end

  local unit = utils.math.round(time)
  local how_long = unit <= 1 and time_postfix:sub(1, #time_postfix - 1)
    or time_postfix

  return {
    unit = unit,
    how_long = how_long,
    display = string.format('%s %s ago', unit, how_long),
  }
end

function utils.math.round(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

function utils.math.uuid()
  local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'

  return string.gsub(template, '[xy]', function(c)
    local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)

    return string.format('%x', v)
  end)
end

function utils.math.scale_unit_up(unit, percent)
  return math.floor(unit * (100 + percent) / 100)
end

function utils.math.scale_unit_down(unit, percent)
  unit = math.floor(unit * (100 - percent) / 100)

  if unit < 1 then
    unit = 1
  end

  return unit
end

function utils.str.length(str)
  local _, count = string.gsub(str, '[^\128-\193]', '')

  return count
end

function utils.str.shorten(str, limit)
  if #str > limit then
    str = str:sub(1, limit - 3)
    str = str .. '...'
  end

  return str
end

function utils.str.concat(existing_text, new_text)
  local top_range = #existing_text
  local end_range = top_range + #new_text
  local text = existing_text .. new_text

  return text, {
    top = top_range,
    bot = end_range,
  }
end

function utils.str.strip(given_string, substring)
  if substring == '' then
    return given_string
  end

  local rc_s = ''
  local i = 1
  local found = false

  while i <= #given_string do
    local temp_i = 0

    if not found then
      for j = 1, #substring do
        local s_j = substring:sub(j, j)
        local s_i = given_string:sub(i + temp_i, i + temp_i)

        if s_j == s_i then
          temp_i = temp_i + 1
        end
      end
    end
    if temp_i == #substring then
      found = true
      i = i + temp_i
    else
      rc_s = rc_s .. given_string:sub(i, i)
      i = i + 1
    end
  end

  return rc_s
end

function utils.object.first(object)
  object = object or {}

  for _, value in pairs(object) do
    return value
  end

  return nil
end

function utils.object.size(object)
  object = object or {}
  local count = 0

  for _ in pairs(object) do
    count = count + 1
  end

  return count
end

function utils.object.defaults(object, ...)
  object = object or {}
  local objects = { ... }

  for i = 1, #objects do
    object = vim.tbl_deep_extend('keep', object, objects[i])
  end

  return object
end

function utils.object.assign(object, ...)
  object = object or {}
  local objects = { ... }

  for i = 1, #objects do
    object = vim.tbl_deep_extend('force', object, objects[i])
  end

  return object
end

function utils.object.merge(...)
  local object = {}
  local objects = { ... }

  for i = 1, #objects do
    object = vim.tbl_deep_extend('force', object, objects[i])
  end

  return object
end

function utils.object.each(object, callback)
  local pairs = {}

  for key, component in pairs(object) do
    callback(component, key)
  end

  return pairs
end

function utils.object.pairs(object)
  local pairs = {}

  for key, component in pairs(object) do
    pairs[#pairs + 1] = { key, component }
  end

  return pairs
end

function utils.object.keys(object)
  local keys = {}

  for key, _ in pairs(object) do
    keys[#keys + 1] = key
  end

  return keys
end

function utils.object.values(object)
  local values = {}

  for _, value in pairs(object) do
    values[#values + 1] = value
  end

  return values
end

function utils.object.clone_deep(config_object)
  return vim.tbl_deep_extend('force', {}, config_object)
end

function utils.object.clone(config_object)
  return vim.tbl_extend('force', {}, config_object)
end

function utils.object.each(object, callback)
  for key, value in pairs(object) do
    local break_loop = callback(value, key)

    if break_loop then
      return
    end
  end
end

utils.object.is_empty = vim.tbl_isempty

function utils.list.pick(list, item)
  for i = 1, #list do
    if list[i] == item then
      return item
    end
  end

  return list[1]
end

function utils.list.concat(a, b)
  for i = 1, #b do
    a[#a + 1] = b[i]
  end

  return a
end

function utils.list.merge(t, ...)
  local a = vim.deepcopy(t)
  local lists = { ... }

  for i = 1, #lists do
    local b = lists[i]

    for _, value in ipairs(b) do
      a[#a + 1] = value
    end
  end

  return a
end

function utils.list.map(list, callback)
  local new_list = {}

  for i = 1, #list do
    new_list[#new_list + 1] = callback(list[i], i)
  end

  return new_list
end

function utils.list.filter(list, callback)
  local new_list = {}

  for i = 1, #list do
    local list_item = list[i]
    local result = callback(list_item, i)

    if result then
      new_list[#new_list + 1] = list_item
    end
  end

  return new_list
end

function utils.list.each(list, callback)
  for i = 1, #list do
    local break_loop = callback(list[i], i)

    if break_loop then
      return
    end
  end
end

function utils.list.reduce(list, accumulator, callback)
  for i = 1, #list do
    accumulator = callback(accumulator, list[i], i)
  end

  return accumulator
end

function utils.list.find(list, callback)
  for i = 1, #list do
    local item = list[i]
    local found = callback(item, i)

    if found then
      return item
    end
  end
end

utils.list.is_list = vim.tbl_islist

utils.list.is_empty = vim.tbl_isempty

return utils
