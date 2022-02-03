local utils = require('vgit.core.utils')
local dimensions = {}

dimensions.global_width = function()
  return vim.o.columns
end

dimensions.global_height = function()
  return vim.o.lines - 1
end

dimensions.vh = function(value)
  return string.format('%svh', value)
end

dimensions.vw = function(value)
  return string.format('%svw', value)
end

dimensions.convert = function(value)
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

dimensions.calculate_text_center = function(text, width)
  local rep = utils.math.round((width / 2) - utils.math.round(#text / 2))
  return (rep < 0 and 0) or rep
end

return dimensions
