local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')

local LayoutBounds = Object:extend()

function LayoutBounds:constructor(opts)
  opts = opts or {}
  return {
    row = opts.row or 0,
    col = opts.col or 0,
    width = opts.width or 0,
    height = opts.height or 0,
    parent = opts.parent or nil,
  }
end

function LayoutBounds.from_viewport()
  return LayoutBounds({
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines,
    parent = nil,
  })
end

function LayoutBounds.from_window(win_id)
  local win = win_id and Window(win_id) or Window(0)

  if not win:is_valid() then return LayoutBounds.from_viewport() end

  local width = win:get_width()
  local height = win:get_height()
  local pos = win:get_position()

  return LayoutBounds({
    row = pos[1],
    col = pos[2],
    width = width,
    height = height,
    parent = nil,
  })
end

function LayoutBounds:parse_dimension(value, parent_dimension)
  return LayoutContext.convert_dimension(value, parent_dimension)
end

function LayoutBounds:apply_constraints(value, min_value, max_value, parent_dimension)
  if not value then return end

  local result = value

  if min_value then
    local min_parsed = self:parse_dimension(min_value, parent_dimension)
    if min_parsed and result < min_parsed then result = min_parsed end
  end

  if max_value then
    local max_parsed = self:parse_dimension(max_value, parent_dimension)
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

  if spec.width then child_width = self:parse_dimension(spec.width, self.width) end
  if spec.height then child_height = self:parse_dimension(spec.height, self.height) end

  child_width = self:apply_constraints(child_width, spec.min_width, spec.max_width, self.width)
  child_height = self:apply_constraints(child_height, spec.min_height, spec.max_height, self.height)

  if spec.anchor then
    child_row, child_col = self:calculate_anchor_position(spec.anchor, child_width, child_height, spec.offset)
  end

  return LayoutBounds({
    row = child_row,
    col = child_col,
    width = child_width,
    height = child_height,
    parent = self,
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
    parent = self.parent,
  })
end

function LayoutBounds:shrink(margin)
  margin = margin or 0
  return LayoutBounds({
    row = self.row + margin,
    col = self.col + margin,
    width = math.max(0, self.width - (margin * 2)),
    height = math.max(0, self.height - (margin * 2)),
    parent = self.parent,
  })
end

function LayoutBounds:available_space(direction)
  if direction == 'horizontal' then
    return self.width
  elseif direction == 'vertical' then
    return self.height
  end
  return 0
end

return LayoutBounds
