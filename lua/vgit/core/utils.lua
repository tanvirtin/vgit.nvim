local utils = {}

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
  local start_range = #existing_text
  local end_range = start_range + #new_text
  local text = existing_text .. new_text
  return text, {
    start = start_range,
    finish = end_range,
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
