local utils = require('vgit.core.utils')
local ComponentPlot = require('vgit.ui.ComponentPlot')
local Window = require('vgit.core.Window')
local Namespace = require('vgit.core.Namespace')
local Notification = require('vgit.ui.decorations.Notification')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')

local AppBarComponent = Component:extend()

function AppBarComponent:constructor(props)
  return utils.object.assign(Component.constructor(self), {
    config = {
      elements = {
        header = false,
        line_number = false,
        footer = false,
      },
    },
  }, props)
end

function AppBarComponent:call(callback)
  self.window:call(callback)

  return self
end

function AppBarComponent:get_height() return 1 end

function AppBarComponent:set_default_win_plot(win_plot)
  win_plot.focusable = false
  win_plot.zindex = 3
  win_plot.height = 1

  return self
end

function AppBarComponent:set_default_win_options(win_options)
  win_options.winhl = 'Normal:GitAppBar'

  return self
end

function AppBarComponent:mount(opts)
  if self.mounted then
    return self
  end

  local config = self.config
  local win_plot = config.win_plot
  local win_options = config.win_options
  local elements_config = config.elements

  self:set_default_win_plot(win_plot):set_default_win_options(win_options)

  local plot = ComponentPlot(config.win_plot, utils.object.merge(elements_config, opts)):build()

  self.notification = Notification()
  self.namespace = Namespace()
  self.buffer = Buffer():create():assign_options(config.buf_options)

  local buffer = self.buffer

  self.window = Window:open(buffer, plot.win_plot):assign_options(win_options)

  self.mounted = true
  self.plot = plot

  return self
end

function AppBarComponent:unmount()
  self.window:close()

  return self
end

function AppBarComponent:clear_notification()
  if self.buffer:is_valid() then
    self.namespace:clear(self.buffer)
  end

  return self
end

function AppBarComponent:trigger_notification(text)
  self.namespace:transpose_virtual_text(self.buffer, text, 'GitComment', 0, 0, 'eol')

  return self
end

function AppBarComponent:notify(text)
  self.notification:notify(self, text)

  return self
end

return AppBarComponent
