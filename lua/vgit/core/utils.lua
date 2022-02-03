local assertion = require('vgit.core.assertion')

-- Standard utility functions used throughout the app.

local utils = {
  object = {},
  list = {},
  time = {},
  math = {},
  str = {},
}

utils.time.age = function(current_time)
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

utils.math.round = function(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

utils.str.length = function(str)
  local _, count = string.gsub(str, '[^\128-\193]', '')
  return count
end

utils.str.shorten = function(str, limit)
  if #str > limit then
    str = str:sub(1, limit - 3)
    str = str .. '...'
  end
  return str
end

utils.str.concat = function(existing_text, new_text)
  local top_range = #existing_text
  local end_range = top_range + #new_text
  local text = existing_text .. new_text
  return text, {
    top = top_range,
    bot = end_range,
  }
end

utils.str.strip = function(given_string, substring)
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

utils.object.defaults = function(object, ...)
  object = object or {}
  local objects = { ... }
  for i = 1, #objects do
    object = vim.tbl_deep_extend('keep', object, objects[i])
  end
  return object
end

utils.object.assign = function(object, ...)
  object = object or {}
  local objects = { ... }
  for i = 1, #objects do
    object = vim.tbl_deep_extend('force', object, objects[i])
  end
  return object
end

utils.object.merge = function(...)
  local object = {}
  local objects = { ... }
  for i = 1, #objects do
    object = vim.tbl_deep_extend('force', object, objects[i])
  end
  return object
end

utils.object.clone_deep = function(config_object)
  return vim.tbl_deep_extend('force', {}, config_object)
end

utils.object.clone = function(config_object)
  return vim.tbl_extend('force', {}, config_object)
end

utils.object.pick = function(object, item)
  for i = 1, #object do
    if object[i] == item then
      return item
    end
  end
  return object[1]
end

utils.object.each = function(object, callback)
  for key, value in pairs(object) do
    local break_loop = callback(value, key)
    if break_loop then
      return
    end
  end
end

utils.list.concat = function(a, b)
  for i = 1, #b do
    a[#a + 1] = b[i]
  end
  return a
end

utils.list.map = function(list, callback)
  local new_list = {}
  for i = 1, #list do
    new_list[#new_list + 1] = callback(list[i], i)
  end
  return new_list
end

utils.list.filter = function(list, callback)
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

utils.list.is_list = vim.tbl_islist

utils.list.each = function(list, callback)
  for i = 1, #list do
    local break_loop = callback(list[i], i)
    if break_loop then
      return
    end
  end
end

return utils
