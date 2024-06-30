local utils = require('vgit.core.utils')

local dimensions = {}

function dimensions.global_width()
  local dim = vim.o.columns
  -- NOTE: we want width to be divisible by 1
  if dim % 2 ~= 0 then
    if dim == 1 then return dim end
    return dim - 1
  end
  return dim
end

function dimensions.global_height()
  return vim.o.lines
end

function dimensions.vh(value)
  return string.format('%svh', value)
end

function dimensions.vw(value)
  return string.format('%svw', value)
end

function dimensions.get_value(size)
  return tonumber(size:sub(1, #size - 2))
end

function dimensions.get_unit(size)
  return size:sub(#size - 1, #size)
end

function dimensions.relative_size(parent, child, op)
  if not child then return parent end

  if not parent then return child end

  -- TODO: Can relativity be applied on integers?
  if type(child) == 'number' then return child end
  -- TODO: Can relativity be applied on integers?
  if type(parent) == 'number' then return parent end

  local parent_value = dimensions.get_value(parent)
  local child_value = dimensions.get_value(child)

  if parent_value == 0 then return child end

  local ratio = child_value / 100
  if ratio == 0 then return parent end

  local value = ratio * parent_value
  local unit = dimensions.get_unit(parent)

  if op == 'add' then value = child_value + value end
  if op == 'remove' then value = child_value - value end

  return string.format('%s%s', value, unit)
end

-- Get dimension of child in relation to parent.
function dimensions.relative_win_plot(parent, child)
  parent = parent or {}
  child = child or {}

  return {
    relative = child.relative or parent.relative,
    height = dimensions.relative_size(parent.height, child.height),
    width = dimensions.relative_size(parent.width, child.width),
    row = dimensions.relative_size(parent.row, child.row, 'add'),
    col = dimensions.relative_size(parent.col, child.col, 'add'),
    zindex = child.zindex,
  }
end

function dimensions.convert(value)
  if type(value) == 'string' then
    local number_value = value:sub(1, #value - 2)
    local type = value:sub(#value - 1, #value)

    if type == 'vh' then return utils.math.round((tonumber(number_value) / 100) * dimensions.global_height()) end
    if type == 'vw' then return utils.math.round((tonumber(number_value) / 100) * dimensions.global_width()) end

    error(debug.traceback('error :: invalid dimension, should either be \'vh\' or \'vw\''))
  end

  return value
end

function dimensions.calculate_text_center(text, width)
  local rep = utils.math.round((width / 2) - utils.math.round(#text / 2))

  return (rep < 0 and 0) or rep
end

return dimensions
