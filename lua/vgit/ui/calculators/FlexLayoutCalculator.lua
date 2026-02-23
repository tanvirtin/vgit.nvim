local lazy = require('vgit.core.lazy')
local BaseLayoutCalculator = lazy('vgit.ui.calculators.BaseLayoutCalculator')

local FlexLayoutCalculator = BaseLayoutCalculator:extend()

function FlexLayoutCalculator:calculate_flex(spec, parent_bounds)
  local direction = spec.direction or 'horizontal'
  local gap = spec.gap or 0
  local children = spec.children or {}

  if #children == 0 then return {
    bounds = parent_bounds,
    spec = spec,
    children = {},
  } end

  local main_axis_size = direction == 'horizontal' and parent_bounds.width or parent_bounds.height
  local cross_axis_size = direction == 'horizontal' and parent_bounds.height or parent_bounds.width

  local total_gap_space = gap * (#children - 1)
  local available_space = main_axis_size - total_gap_space

  local fixed_children = {}
  local flex_children = {}
  local total_fixed_size = 0
  local total_flex = 0

  for i, child in ipairs(children) do
    local dimension_key = direction == 'horizontal' and 'width' or 'height'
    local fixed_size = child[dimension_key]

    if fixed_size then
      local parsed_size = parent_bounds:parse_dimension(fixed_size, main_axis_size, dimension_key)
      if parsed_size then
        fixed_children[i] = parsed_size
        total_fixed_size = total_fixed_size + parsed_size
      else
        flex_children[i] = child.flex or 1
        total_flex = total_flex + (child.flex or 1)
      end
    else
      flex_children[i] = child.flex or 1
      total_flex = total_flex + (child.flex or 1)
    end
  end

  local flex_space = available_space - total_fixed_size
  if flex_space < 0 then flex_space = 0 end

  local child_sizes = {}

  for i, child in ipairs(children) do
    if fixed_children[i] then
      child_sizes[i] = fixed_children[i]
    else
      local flex_ratio = flex_children[i]
      local size = total_flex > 0 and math.floor((flex_ratio / total_flex) * flex_space) or 0
      child_sizes[i] = size
    end
  end

  local total_allocated = 0
  for _, size in ipairs(child_sizes) do
    total_allocated = total_allocated + size
  end
  local remainder = available_space - total_allocated
  if remainder > 0 and #children > 0 then
    local flex_children_count = 0
    for _, is_flex in ipairs(flex_children) do
      if is_flex then flex_children_count = flex_children_count + 1 end
    end

    if flex_children_count > 0 then
      local remainder_per_child = math.floor(remainder / flex_children_count)
      local extra_remainder = remainder % flex_children_count

      for i = 1, #children do
        if flex_children[i] then
          child_sizes[i] = child_sizes[i] + remainder_per_child
          if extra_remainder > 0 then
            child_sizes[i] = child_sizes[i] + 1
            extra_remainder = extra_remainder - 1
          end
        end
      end
    end
  end

  local child_layouts = {}
  local current_pos = 0

  for i, child in ipairs(children) do
    local child_size = child_sizes[i]

    local child_allocated
    if direction == 'horizontal' then
      child_allocated = {
        row = parent_bounds.row,
        col = parent_bounds.col + current_pos,
        width = child_size,
        height = cross_axis_size,
      }
    else
      child_allocated = {
        row = parent_bounds.row + current_pos,
        col = parent_bounds.col,
        width = cross_axis_size,
        height = child_size,
      }
    end

    local child_bounds = parent_bounds:child_bounds(child, child_allocated)

    local child_layout = self:calculate(child, child_bounds)
    table.insert(child_layouts, child_layout)

    current_pos = current_pos + child_size + gap
  end

  return {
    bounds = parent_bounds,
    spec = spec,
    children = child_layouts,
  }
end

return FlexLayoutCalculator
