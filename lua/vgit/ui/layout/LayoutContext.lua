local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local dimensions = lazy('vgit.ui.dimensions')
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

  return {
    ['$mode'] = config.mode or 'popup', -- 'screen', 'lens', 'popup'
    ['$width'] = config.width,
    ['$height'] = config.height,
    ['$zindex'] = config.zindex or 2,
    ['$relative'] = config.relative or 'editor',
    ['$position'] = config.position or 'center',
    ['$original_win_options'] = LayoutContext.capture_window_options(),
  }
end

function LayoutContext.capture_window_options()
  local win_options = {}
  local win = Window.get_current()
  if not win or not win:is_valid() then return end

  for _, option_name in ipairs(LayoutContext.WINDOW_OPTIONS) do
    local value = win:get_option(option_name)
    if value ~= nil then win_options[option_name] = value end
  end

  return win_options
end

function LayoutContext.convert_dimension(value, parent_dimension)
  if not value then return nil end

  if type(value) == 'number' then return math.floor(value) end

  if type(value) == 'string' then
    if value:match('%%$') then
      local percent = tonumber(value:match('^(.-)%%$'))
      if percent and parent_dimension then return math.floor((percent / 100) * parent_dimension) end
    end

    if value:match('vh$') or value:match('vw$') then return dimensions.convert(value) end
  end
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

function LayoutContext:is_floating_mode()
  return self.mode == 'lens' or self.mode == 'popup'
end

function LayoutContext:get_dimensions()
  return {
    width = LayoutContext.convert_dimension(self.width),
    height = LayoutContext.convert_dimension(self.height),
  }
end

function LayoutContext:derive(overrides)
  overrides = overrides or {}

  return LayoutContext({
    mode = overrides.mode or self.mode,
    width = overrides.width or self.width,
    height = overrides.height or self.height,
    zindex = overrides.zindex or self.zindex,
    relative = overrides.relative or self.relative,
    position = overrides.position or self.position,
  })
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
  else
    return viewport_bounds
  end
end

function LayoutContext:create_lens_bounds(viewport_bounds)
  local cursor_row = vim.fn.winline() - 1 -- Convert to 0-based

  -- Position lens 1 row below cursor (not at cursor)
  local lens_start_row = cursor_row + 1

  local available_height = viewport_bounds.height - lens_start_row

  local dims = self:get_dimensions()
  local requested_height = dims.height or available_height

  local final_row = lens_start_row
  local final_height = requested_height

  if requested_height > available_height then
    -- Not enough space below cursor - shift lens upward
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

  local win = Window.get_current()
  if not win or not win:is_valid() then return end

  pcall(function()
    win:assign_options(self.original_win_options)
  end)

  return self
end

return LayoutContext
