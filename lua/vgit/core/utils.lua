local assertion = require('vgit.core.assertion')
local utils = {}

utils.age = function(current_time)
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
  local unit = utils.round(time)
  local how_long = unit <= 1 and time_postfix:sub(1, #time_postfix - 1)
    or time_postfix
  return {
    unit = unit,
    how_long = how_long,
    display = string.format('%s %s ago', unit, how_long),
  }
end

utils.retrieve = function(cmd, ...)
  if type(cmd) == 'function' then
    return cmd(...)
  end
  return cmd
end

utils.round = function(x)
  return x >= 0 and math.floor(x + 0.5) or math.ceil(x - 0.5)
end

utils.shorten_string = function(str, limit)
  if #str > limit then
    str = str:sub(1, limit - 3)
    str = str .. '...'
  end
  return str
end

utils.accumulate_string = function(existing_text, new_text)
  local top_range = #existing_text
  local end_range = top_range + #new_text
  local text = existing_text .. new_text
  return text, {
    top = top_range,
    bot = end_range,
  }
end

utils.strip_substring = function(given_string, substring)
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

-- Does deep object assign
utils.object_assign = function(state_segment, config_segment)
  if type(config_segment) == 'table' and not vim.tbl_islist(config_segment) then
    for key, value in pairs(config_segment) do
      if not state_segment[key] then
        state_segment[key] = value
      else
        if type(value) == 'table' and not vim.tbl_islist(value) then
          utils.object_assign(state_segment[key], value)
        else
          state_segment[key] = value
        end
      end
    end
  end
  return state_segment
end

utils.list_concat = function(a, b)
  for i = 1, #b do
    a[#a + 1] = b[i]
  end
  return a
end

return utils
