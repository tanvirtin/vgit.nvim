local lazy = require('vgit.core.lazy')

local LayoutBounds = lazy('vgit.ui.layout.LayoutBounds')
local BaseLayoutCalculator = lazy('vgit.ui.calculators.BaseLayoutCalculator')

local AbsoluteLayoutCalculator = BaseLayoutCalculator:extend()

function AbsoluteLayoutCalculator:calculate_absolute(spec, parent_bounds)
  local width = parent_bounds:parse_dimension(spec.width, parent_bounds.width, 'width') or parent_bounds.width
  local height = parent_bounds:parse_dimension(spec.height, parent_bounds.height, 'height') or parent_bounds.height

  width = parent_bounds:apply_constraints(width, spec.min_width, spec.max_width, parent_bounds.width)
  height = parent_bounds:apply_constraints(height, spec.min_height, spec.max_height, parent_bounds.height)

  local row, col

  if spec.anchor then
    if spec.row or spec.col then
      local ref_row = parent_bounds.row + (parent_bounds:parse_dimension(spec.row, parent_bounds.height, 'height') or 0)
      local ref_col = parent_bounds.col + (parent_bounds:parse_dimension(spec.col, parent_bounds.width, 'width') or 0)
      local ref_bounds = LayoutBounds({
        row = ref_row,
        col = ref_col,
        width = 1,
        height = 1,
      })
      row, col = ref_bounds:calculate_anchor_position(spec.anchor, width, height, spec.offset)
    else
      row, col = parent_bounds:calculate_anchor_position(spec.anchor, width, height, spec.offset)
    end
  else
    row = parent_bounds.row + (parent_bounds:parse_dimension(spec.row, parent_bounds.height, 'height') or 0)
    col = parent_bounds.col + (parent_bounds:parse_dimension(spec.col, parent_bounds.width, 'width') or 0)
  end

  local bounds = LayoutBounds({
    row = row,
    col = col,
    width = width,
    height = height,
    parent = parent_bounds,
  })

  local children = {}
  if spec.child then
    local child_layout = self:calculate(spec.child, bounds)
    table.insert(children, child_layout)
  end

  return {
    bounds = bounds,
    spec = spec,
    children = children,
  }
end

return AbsoluteLayoutCalculator
