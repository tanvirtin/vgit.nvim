local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local RootLayoutCalculator = lazy('vgit.ui.calculators.RootLayoutCalculator')

local LayoutRenderer = Object:extend()

function LayoutRenderer:constructor(context)
  if not context then error('LayoutRenderer requires LayoutContext') end

  return {
    ['$context'] = context,
    ['$windows'] = {},
    window_index = 0,
    ['$calculator'] = RootLayoutCalculator(),
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

  view:set_window_mode(self.context.mode)

  local win_plot = bounds:to_win_plot({
    relative = 'editor',
    zindex = spec.zindex or 2,
    focus = spec.focus or false,
  })

  view:apply_layout_win_plot(win_plot)

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

  local function create_splits_for_layout(node)
    if node.spec.type == LayoutSpec.Type.VIEW then
      table.insert(self.windows, Window(0))
      return
    end

    local children = node.children or {}
    if #children == 0 then return end

    local split_cmd = 'vsplit'
    if node.spec.type == LayoutSpec.Type.FLEX and node.spec.direction == LayoutSpec.Direction.VERTICAL then
      split_cmd = 'split'
    end

    -- Collect all window IDs at this FLEX level BEFORE recursing into children
    local child_wins = {}
    child_wins[1] = Window.get_current()
    for i = 2, #children do
      vim.cmd(split_cmd)
      child_wins[i] = Window.get_current()
    end

    -- Navigate to each child window and recurse into it
    for i, child in ipairs(children) do
      child_wins[i]:focus()
      create_splits_for_layout(child)
    end
  end

  create_splits_for_layout(layout)
end

function LayoutRenderer:render(spec, parent_bounds)
  if not parent_bounds then parent_bounds = self.context:create_parent_bounds() end

  local layout = self.calculator:calculate(spec, parent_bounds, self.context)

  if self.context:is_screen_mode() then self:create_screen_splits(layout) end
  self:render_layout(layout)

  return layout
end

return LayoutRenderer
