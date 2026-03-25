local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local LayoutBounds = Object:extend()

function LayoutBounds:constructor(opts)
  opts = opts or {}
  return {
    ['$row'] = opts.row or 0,
    ['$col'] = opts.col or 0,
    ['$width'] = opts.width or 0,
    ['$height'] = opts.height or 0,
  }
end

function LayoutBounds.convert_dimension(value, parent_dimension)
  if not value then return nil end

  if type(value) == 'number' then return math.floor(value) end

  if type(value) == 'string' then
    if value:match('%%$') then
      local percent = tonumber(value:match('^(.-)%%$'))
      if percent and parent_dimension then return math.floor((percent / 100) * parent_dimension) end
    end

    if value:match('vh$') then
      local n = tonumber(value:sub(1, #value - 2))
      if n then return math.floor((n / 100) * vim.o.lines) end
    end

    if value:match('vw$') then
      local n = tonumber(value:sub(1, #value - 2))
      if n then return math.floor((n / 100) * vim.o.columns) end
    end
  end
end

function LayoutBounds.from_viewport()
  return LayoutBounds({
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines,
  })
end

function LayoutBounds.apply_constraints(value, min_value, max_value, parent_dimension)
  if not value then return end

  local result = value

  if min_value then
    local min_parsed = LayoutBounds.convert_dimension(min_value, parent_dimension)
    if min_parsed and result < min_parsed then result = min_parsed end
  end

  if max_value then
    local max_parsed = LayoutBounds.convert_dimension(max_value, parent_dimension)
    if max_parsed and result > max_parsed then result = max_parsed end
  end

  return result
end

function LayoutBounds:calculate_anchor_position(anchor, child_width, child_height, offset)
  offset = offset or { row = 0, col = 0 }
  local row_offset = offset.row or 0
  local col_offset = offset.col or 0

  local row, col

  local vertical, horizontal
  if anchor:match('top') then
    vertical = 'top'
  elseif anchor:match('bottom') then
    vertical = 'bottom'
  else
    vertical = 'center'
  end

  if anchor:match('left') then
    horizontal = 'left'
  elseif anchor:match('right') then
    horizontal = 'right'
  else
    horizontal = 'center'
  end

  if vertical == 'top' then
    row = self.row + row_offset
  elseif vertical == 'bottom' then
    row = self.row + self.height - child_height - row_offset
  elseif vertical == 'center' then
    row = self.row + math.floor((self.height - child_height) / 2) + row_offset
  end

  if horizontal == 'left' then
    col = self.col + col_offset
  elseif horizontal == 'right' then
    col = self.col + self.width - child_width - col_offset
  elseif horizontal == 'center' then
    col = self.col + math.floor((self.width - child_width) / 2) + col_offset
  end

  return row, col
end

function LayoutBounds:child_bounds(spec, allocated)
  allocated = allocated or {}

  local child_width = allocated.width
  local child_height = allocated.height
  local child_row = allocated.row or self.row
  local child_col = allocated.col or self.col

  if spec.width then child_width = LayoutBounds.convert_dimension(spec.width, self.width) end
  if spec.height then child_height = LayoutBounds.convert_dimension(spec.height, self.height) end

  child_width = LayoutBounds.apply_constraints(child_width, spec.min_width, spec.max_width, self.width)
  child_height = LayoutBounds.apply_constraints(child_height, spec.min_height, spec.max_height, self.height)

  if spec.anchor then
    child_row, child_col = self:calculate_anchor_position(spec.anchor, child_width, child_height, spec.offset)
  end

  return LayoutBounds({
    row = child_row,
    col = child_col,
    width = child_width,
    height = child_height,
  })
end

function LayoutBounds:to_win_plot(opts)
  opts = opts or {}

  local plot = {
    relative = opts.relative or 'editor',
    row = self.row,
    col = self.col,
    width = math.max(1, self.width),
    height = math.max(1, self.height),
    style = opts.style or 'minimal',
    zindex = opts.zindex or 2,
  }

  if opts.focusable ~= nil then
    plot.focusable = opts.focusable
  else
    plot.focusable = true
  end

  return plot
end

function LayoutBounds:clone()
  return LayoutBounds({
    row = self.row,
    col = self.col,
    width = self.width,
    height = self.height,
  })
end

function LayoutBounds:shrink(margin)
  margin = margin or 0
  return LayoutBounds({
    row = self.row + margin,
    col = self.col + margin,
    width = math.max(0, self.width - (margin * 2)),
    height = math.max(0, self.height - (margin * 2)),
  })
end

return LayoutBounds
