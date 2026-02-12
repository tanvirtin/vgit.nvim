local lazy = require('vgit.core.lazy')
local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local RootLayoutCalculator = lazy('vgit.ui.calculators.RootLayoutCalculator')

local LayoutRenderer = Object:extend()

function LayoutRenderer:constructor(context)
  if not context then error('LayoutRenderer requires LayoutContext') end

  return {
    context = context,
    windows = {},
    window_index = 0,
    calculator = RootLayoutCalculator(),
  }
end

function LayoutRenderer:render_container_layout(layout)
  for _, child_layout in ipairs(layout.children) do
    self:render_layout(child_layout)
  end
end

function LayoutRenderer:render_absolute_layout(layout)
  return self:render_container_layout(layout)
end

function LayoutRenderer:render_view_layout(layout)
  local spec = layout.spec
  local view = spec.view
  local bounds = layout.bounds

  if not view then return end

  if self.context:is_screen_mode() and #self.windows > 0 then
    self.window_index = self.window_index + 1
    if self.window_index <= #self.windows then
      local target_window = self.windows[self.window_index]
      if target_window and target_window:is_valid() then target_window:focus() end
    end
  end

  if not view.config then view.config = {} end

  view.config.window_mode = self.context.mode

  if self.context:is_lens_mode() then
    local win_plot = bounds:to_win_plot({
      relative = 'editor',
      zindex = spec.zindex or 2,
      focus = spec.focus or false,
    })

    if view.plot and type(view.plot) == 'table' then
      if view.plot.win_plot then
        local component_focusable = view.plot.win_plot.focusable
        view.plot.win_plot = utils.object.assign(view.plot.win_plot, win_plot)
        if component_focusable ~= nil then view.plot.win_plot.focusable = component_focusable end

        view.plot.is_built = false
        if type(view.plot.build) == 'function' then view.plot:build() end
      else
        view.plot.win_plot = win_plot
      end
    end
  else
    local win_plot = bounds:to_win_plot({
      relative = 'editor',
      zindex = spec.zindex or 2,
      focus = spec.focus or false,
    })

    if view.plot and type(view.plot) == 'table' then
      if view.plot.win_plot then
        local component_focusable = view.plot.win_plot.focusable
        view.plot.win_plot = utils.object.assign(view.plot.win_plot, win_plot)
        if component_focusable ~= nil then view.plot.win_plot.focusable = component_focusable end

        view.plot.is_built = false
        if type(view.plot.build) == 'function' then view.plot:build() end
      else
        view.plot.win_plot = win_plot
      end
    end
  end

  if view.mount then view:mount() end

  if self.context:is_screen_mode() and view.ensure_window_options then
    event.await()
    view:ensure_window_options()
  end

  if spec.focus and type(view.focus) == 'function' then view:focus() end

  return view
end

function LayoutRenderer:render_layout(layout)
  local spec = layout.spec
  local spec_type = spec.type

  if spec_type == LayoutSpec.Type.CONTAINER or spec_type == LayoutSpec.Type.FLEX then
    return self:render_container_layout(layout)
  elseif spec_type == LayoutSpec.Type.ABSOLUTE then
    return self:render_absolute_layout(layout)
  elseif spec_type == LayoutSpec.Type.VIEW then
    return self:render_view_layout(layout)
  end
end

function LayoutRenderer:create_screen_splits(layout)
  if not self.context:is_screen_mode() then return end

  local function create_splits_for_layout(node, is_first)
    if node.spec.type == LayoutSpec.Type.VIEW then
      local current_window = Window(0)
      table.insert(self.windows, current_window)
      return
    end

    local children = node.children or {}
    if #children == 0 then return end

    local split_cmd = 'vsplit' -- side by side
    if node.spec.type == LayoutSpec.Type.FLEX and node.spec.direction == LayoutSpec.Direction.VERTICAL then
      split_cmd = 'split' -- stacked
    end

    create_splits_for_layout(children[1], is_first)

    for i = 2, #children do
      vim.cmd(split_cmd)
      create_splits_for_layout(children[i], false)
    end
  end

  create_splits_for_layout(layout, true)
end

function LayoutRenderer:render(spec, parent_bounds)
  if not parent_bounds then parent_bounds = self.context:create_parent_bounds() end

  local layout = self.calculator:calculate(spec, parent_bounds, self.context)

  if self.context:is_screen_mode() then self:create_screen_splits(layout) end
  self:render_layout(layout)

  return layout
end

return LayoutRenderer
