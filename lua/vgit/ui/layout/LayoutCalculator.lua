local lazy = require('vgit.core.lazy')

local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local LayoutBounds = lazy('vgit.ui.layout.LayoutBounds')

local LayoutCalculator = {}

function LayoutCalculator.apply_mode_wrapping(spec, context)
  if context:is_popup_mode() then
    if spec.type == LayoutSpec.Type.ABSOLUTE then return spec end

    local dims = context:get_dimensions()
    return LayoutSpec.absolute(spec, {
      anchor = LayoutSpec.Anchor.CENTER,
      width = dims.width,
      height = dims.height,
      zindex = context.zindex,
    })
  end

  if context:is_lens_mode() then
    if spec.type and spec.width == nil then
      local dims = context:get_dimensions()
      spec = vim.tbl_extend('force', spec, {
        width = dims.width,
        height = dims.height,
      })
    end
  end

  return spec
end

function LayoutCalculator.calculate(spec, parent_bounds, context)
  if not spec then error('LayoutCalculator.calculate() requires a spec') end

  if not parent_bounds then parent_bounds = LayoutBounds.from_viewport() end
  if context then spec = LayoutCalculator.apply_mode_wrapping(spec, context) end

  local spec_type = spec.type

  if spec_type == LayoutSpec.Type.CONTAINER then
    return LayoutCalculator.calculate_container(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.FLEX then
    return LayoutCalculator.calculate_flex(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.ABSOLUTE then
    return LayoutCalculator.calculate_absolute(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.VIEW then
    return LayoutCalculator.calculate_view(spec, parent_bounds)
  else
    error('Unknown layout type: ' .. tostring(spec_type))
  end
end

function LayoutCalculator.calculate_container(spec, parent_bounds)
  local child_layout = LayoutCalculator.calculate(spec.child, parent_bounds)

  return {
    bounds = parent_bounds,
    spec = spec,
    children = { child_layout },
  }
end

function LayoutCalculator.calculate_view(spec, parent_bounds)
  local allocated = {
    row = parent_bounds.row,
    col = parent_bounds.col,
    width = parent_bounds.width,
    height = parent_bounds.height,
  }

  local bounds = parent_bounds:child_bounds(spec, allocated)

  return {
    bounds = bounds,
    spec = spec,
    children = {},
  }
end

function LayoutCalculator.calculate_flex(spec, parent_bounds)
  local direction = spec.direction or LayoutSpec.Direction.HORIZONTAL
  local gap = spec.gap or 0
  local children = spec.children or {}

  if #children == 0 then return {
    bounds = parent_bounds,
    spec = spec,
    children = {},
  } end

  local main_axis_size = direction == LayoutSpec.Direction.HORIZONTAL and parent_bounds.width or parent_bounds.height
  local cross_axis_size = direction == LayoutSpec.Direction.HORIZONTAL and parent_bounds.height or parent_bounds.width

  local total_gap_space = gap * (#children - 1)
  local available_space = main_axis_size - total_gap_space

  local fixed_children = {}
  local flex_children = {}
  local total_fixed_size = 0
  local total_flex = 0

  for i, child in ipairs(children) do
    local dimension_key = direction == LayoutSpec.Direction.HORIZONTAL and 'width' or 'height'
    local fixed_size = child[dimension_key]

    if fixed_size then
      local parsed_size = LayoutBounds.convert_dimension(fixed_size, main_axis_size)
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

  for i in ipairs(children) do
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
    for i = 1, #children do
      if flex_children[i] then flex_children_count = flex_children_count + 1 end
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
    if direction == LayoutSpec.Direction.HORIZONTAL then
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

    local child_layout = LayoutCalculator.calculate(child, child_bounds)
    table.insert(child_layouts, child_layout)

    current_pos = current_pos + child_size + gap
  end

  return {
    bounds = parent_bounds,
    spec = spec,
    children = child_layouts,
  }
end

function LayoutCalculator.calculate_absolute(spec, parent_bounds)
  local width = LayoutBounds.convert_dimension(spec.width, parent_bounds.width) or parent_bounds.width
  local height = LayoutBounds.convert_dimension(spec.height, parent_bounds.height) or parent_bounds.height

  width = LayoutBounds.apply_constraints(width, spec.min_width, spec.max_width, parent_bounds.width)
  height = LayoutBounds.apply_constraints(height, spec.min_height, spec.max_height, parent_bounds.height)

  local row, col

  if spec.anchor then
    if spec.row or spec.col then
      local ref_row = parent_bounds.row + (LayoutBounds.convert_dimension(spec.row, parent_bounds.height) or 0)
      local ref_col = parent_bounds.col + (LayoutBounds.convert_dimension(spec.col, parent_bounds.width) or 0)
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
    row = parent_bounds.row + (LayoutBounds.convert_dimension(spec.row, parent_bounds.height) or 0)
    col = parent_bounds.col + (LayoutBounds.convert_dimension(spec.col, parent_bounds.width) or 0)
  end

  local bounds = LayoutBounds({
    row = row,
    col = col,
    width = width,
    height = height,
  })

  local children = {}
  if spec.child then
    local child_layout = LayoutCalculator.calculate(spec.child, bounds)
    table.insert(children, child_layout)
  end

  return {
    bounds = bounds,
    spec = spec,
    children = children,
  }
end

return LayoutCalculator
