local Object = require('vgit.core.Object')
local LayoutBounds = require('vgit.ui.layout.LayoutBounds')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')

local BaseLayoutCalculator = Object:extend()

function BaseLayoutCalculator:apply_mode_wrapping(spec, context)
  if context:is_popup_mode() then
    local dims = context:get_dimensions()
    return LayoutSpec.absolute(spec, {
      anchor = 'center',
      width = dims.width,
      height = dims.height,
      zindex = context.zindex,
    })
  end

  if context:is_lens_mode() then
    if spec.type and spec.width == nil then
      local dims = context:get_dimensions()
      spec.width = dims.width
      spec.height = dims.height
    end
  end

  return spec
end

function BaseLayoutCalculator:calculate(spec, parent_bounds, context)
  if not spec then error('BaseLayoutCalculator:calculate() requires a spec') end

  if not parent_bounds then parent_bounds = LayoutBounds.from_viewport() end

  if context then spec = self:apply_mode_wrapping(spec, context) end

  local spec_type = spec.type

  if spec_type == LayoutSpec.Type.CONTAINER then
    return self:calculate_container(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.FLEX then
    return self:calculate_flex(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.ABSOLUTE then
    return self:calculate_absolute(spec, parent_bounds)
  elseif spec_type == LayoutSpec.Type.VIEW then
    return self:calculate_view(spec, parent_bounds)
  else
    error('Unknown layout type: ' .. tostring(spec_type))
  end
end

function BaseLayoutCalculator:calculate_container(spec, parent_bounds)
  local child_layout = self:calculate(spec.child, parent_bounds)

  return {
    bounds = parent_bounds,
    spec = spec,
    children = { child_layout },
  }
end

function BaseLayoutCalculator:calculate_view(spec, parent_bounds)
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

return BaseLayoutCalculator
