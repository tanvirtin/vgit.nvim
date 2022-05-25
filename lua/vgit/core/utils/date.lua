local math = require('vgit.core.utils.math')
local assertion = require('vgit.core.assertion')

local date = {}

function date.format(time, format)
  format = format or '%d %b %Y'

  return os.date(format, tonumber(time))
end

function date.age(current_time)
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

  local unit = math.round(time)
  local how_long = unit <= 1 and time_postfix:sub(1, #time_postfix - 1)
    or time_postfix

  return {
    unit = unit,
    how_long = how_long,
    display = string.format('%s %s ago', unit, how_long),
  }
end

return date
