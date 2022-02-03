local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')

local Scene = Object:extend()

function Scene:new(components)
  return setmetatable({
    components = components,
    state = {
      default_global_opts = {},
    },
    win_toggle_queue = {},
  }, Scene)
end

function Scene:trigger_keypress(key, ...)
  for _, component in pairs(self.components) do
    component:trigger_keypress(key, ...)
  end
end

function Scene:get_windows()
  local windows = {}
  for _, component in pairs(self.components) do
    windows[#windows + 1] = component.window
  end
  return windows
end

function Scene:get_focused_component()
  for _, component in pairs(self.components) do
    if component:is_focused() then
      return component
    end
  end
end

function Scene:get_focused_component_name()
  for name, component in pairs(self.components) do
    if component:is_focused() then
      return name
    end
  end
end

function Scene:keep_focused()
  local windows = self:get_windows()
  local current_window = Window:new(0)
  if #windows > 1 then
    local found = false
    for i = 1, #windows do
      local window = windows[i]
      if current_window:is_same(window) then
        found = true
        break
      end
    end
    if not found then
      if vim.tbl_isempty(self.win_toggle_queue) then
        self.win_toggle_queue = self:get_windows()
      end
      local window = table.remove(self.win_toggle_queue)
      if window:is_valid() then
        window:focus()
      end
    else
      self.win_toggle_queue = self:get_windows()
    end
  else
    local window = windows[1]
    if window:is_valid() then
      window:focus()
    end
  end
end

function Scene:override_defaults()
  -- TODO: Focus scroll on neovim is buggy as it does not respect scrollbind, remove this if resolved in the future.
  self.state.default_global_opts.mouse = vim.o.mouse
  vim.o.mouse = ''
end

function Scene:restore_defaults()
  -- TODO: Focus scroll on neovim is buggy as it does not respect scrollbind, remove this if resolved in the future.
  vim.o.mouse = self.state.default_global_opts.mouse
end

function Scene:mount()
  self:override_defaults()
  local winline = vim.fn.winline()
  for _, component in pairs(self.components) do
    component:mount({ winline = winline })
  end
  return self
end

function Scene:unmount()
  self:restore_defaults()
  for _, component in pairs(self.components) do
    component:unmount()
  end
  return self
end

return Scene
