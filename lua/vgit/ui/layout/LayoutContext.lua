local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local LayoutBounds = lazy('vgit.ui.layout.LayoutBounds')

local LayoutContext = Object:extend()

LayoutContext.WINDOW_OPTIONS = {
  'wrap',
  'winhl',
  'number',
  'cursorline',
  'signcolumn',
  'foldcolumn',
  'scrollbind',
  'cursorbind',
  'cursorcolumn',
  'relativenumber',
}

function LayoutContext:constructor(config)
  config = config or {}

  local captured = LayoutContext.capture_window_options()

  return {
    ['$mode'] = config.mode or 'popup',
    ['$width'] = config.width,
    ['$height'] = config.height,
    ['$zindex'] = config.zindex or 2,
    ['$original_win_options'] = captured and captured.options,
    ['$original_win_id'] = captured and captured.win_id,
  }
end

function LayoutContext.capture_window_options()
  local win = Window.get_current()
  if not win or not win:is_valid() then return nil end

  local win_options = {}
  for _, option_name in ipairs(LayoutContext.WINDOW_OPTIONS) do
    local value = win:get_option(option_name)
    if value ~= nil then win_options[option_name] = value end
  end

  return { options = win_options, win_id = win.win_id }
end

function LayoutContext:is_screen_mode()
  return self.mode == 'screen'
end

function LayoutContext:is_lens_mode()
  return self.mode == 'lens'
end

function LayoutContext:is_popup_mode()
  return self.mode == 'popup'
end

function LayoutContext:is_split_mode()
  return self.mode == 'split'
end

function LayoutContext:is_floating_mode()
  return self.mode == 'lens' or self.mode == 'popup'
end

function LayoutContext:get_dimensions()
  return {
    width = LayoutBounds.convert_dimension(self.width),
    height = LayoutBounds.convert_dimension(self.height),
  }
end

function LayoutContext:get_props_for_component()
  return {
    mode = self.mode,
    dimensions = self:get_dimensions(),
    zindex = self.zindex,
  }
end

function LayoutContext:create_parent_bounds()
  local viewport_bounds = LayoutBounds.from_viewport()

  if self:is_lens_mode() then
    return self:create_lens_bounds(viewport_bounds)
  elseif self:is_split_mode() then
    local dims = self:get_dimensions()
    return LayoutBounds({
      row = 0,
      col = 0,
      width = dims.width or viewport_bounds.width,
      height = dims.height or viewport_bounds.height,
    })
  else
    return viewport_bounds
  end
end

function LayoutContext:create_lens_bounds(viewport_bounds)
  local cursor_row = vim.fn.winline() - 1

  local lens_start_row = cursor_row + 1

  local available_height = viewport_bounds.height - lens_start_row

  local dims = self:get_dimensions()
  local requested_height = dims.height or available_height

  local final_row = lens_start_row
  local final_height = requested_height

  if requested_height > available_height then
    local overflow = requested_height - available_height
    final_row = math.max(0, lens_start_row - overflow)
    final_height = math.min(requested_height, viewport_bounds.height)
  end

  return LayoutBounds({
    row = final_row,
    col = 0,
    width = viewport_bounds.width,
    height = final_height,
  })
end

function LayoutContext:restore_window_options()
  if not self.original_win_options then return end

  local win
  if self.original_win_id then
    win = Window(self.original_win_id)
  else
    win = Window.get_current()
  end
  if not win or not win:is_valid() then return end

  pcall(function()
    win:assign_options(self.original_win_options)
  end)

  return self
end

return LayoutContext
