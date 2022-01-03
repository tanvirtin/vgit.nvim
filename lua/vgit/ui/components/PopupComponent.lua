local utils = require('vgit.core.utils')
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

local PopupComponent = Component:extend()

function PopupComponent:new(options)
  return setmetatable(Component:new(options), PopupComponent)
end

function PopupComponent:call(callback)
  self.window:call(callback)
  return self
end

function PopupComponent:get_dimensions(window_props)
  return {
    window_props = utils.object_assign(window_props, {
      relative = 'cursor',
    }),
    global_window_props = window_props,
  }
end

function PopupComponent:mount()
  if self.mounted then
    return self
  end
  local config = self.config
  local component_dimensions = self:get_dimensions(config.window_props)
  local window_props = component_dimensions.window_props

  self.buffer = Buffer:new():create():assign_options(config.buf_options)

  window_props.border = self:make_border({
    hl = 'GitBorder',
    chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  })

  self.window = Window
    :open(self.buffer, window_props)
    :assign_options(config.win_options)

  self.mounted = true
  self.component_dimensions = component_dimensions

  return self
end

function PopupComponent:unmount()
  self.window:close()
  return self
end

return PopupComponent
