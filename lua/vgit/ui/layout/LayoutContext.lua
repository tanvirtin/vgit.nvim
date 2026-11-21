local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local LensRoom = lazy('vgit.ui.layout.LensRoom')
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
    ['$original_bufnr'] = captured and captured.bufnr,
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

  return {
    options = win_options,
    win_id = win.win_id,
    bufnr = vim.api.nvim_win_get_buf(win.win_id),
  }
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
  local win_id = self.original_win_id or vim.api.nvim_get_current_win()

  if not vim.api.nvim_win_is_valid(win_id) then return viewport_bounds end

  self:release_room()

  local room = LensRoom.reserve(win_id, self:get_dimensions().height)

  self.room = room

  return LayoutBounds({
    row = room.row,
    col = room.col,
    width = room.width,
    height = room.height,
  })
end

function LayoutContext:release_room()
  if not self.room then return self end

  LensRoom.release(self.room)
  self.room = nil

  return self
end

function LayoutContext:restore_window_options()
  self:release_room()

  if not self.original_win_options then return end

  local win
  if self.original_win_id then
    win = Window(self.original_win_id)
  else
    win = Window.get_current()
  end
  if not win or not win:is_valid() then return end

  -- the window may have moved on to another buffer while the view was open;
  -- its options belong to that buffer now, not to the one that was captured
  if self.original_bufnr and vim.api.nvim_win_get_buf(win.win_id) ~= self.original_bufnr then return self end

  pcall(function()
    win:assign_options(self.original_win_options)
  end)

  return self
end

return LayoutContext
