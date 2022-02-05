local utils = require('vgit.core.utils')
local dimensions = {}

function dimensions.global_width()
  return vim.o.columns
end

function dimensions.global_height()
  return vim.o.lines - 1
end

function dimensions.vh(value)
  return string.format('%svh', value)
end

function dimensions.vw(value)
  return string.format('%svw', value)
end

function dimensions.convert(value)
  if type(value) == 'string' then
    local number_value = value:sub(1, #value - 2)
    local type = value:sub(#value - 1, #value)
    if type == 'vh' then
      return utils.math.round(
        (tonumber(number_value) / 100) * dimensions.global_height()
      )
    end
    if type == 'vw' then
      return utils.math.round(
        (tonumber(number_value) / 100) * dimensions.global_width()
      )
    end
    error(
      debug.traceback(
        'error :: invalid dimension, should either be \'vh\' or \'vw\''
      )
    )
  end
  return value
end

function dimensions.calculate_text_center(text, width)
  local rep = utils.math.round((width / 2) - utils.math.round(#text / 2))
  return (rep < 0 and 0) or rep
end

return dimensions
