local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Notification = require('vgit.ui.decorations.Notification')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')

local AppBarComponent = Component:extend()

function AppBarComponent:constructor(props)
  props = utils.object.assign({
    config = {
      elements = {
        header = false,
        footer = false,
      },
    },
  }, props)
  return Component.constructor(self, props)
end

function AppBarComponent:call(callback)
  self.window:call(callback)
  return self
end

function AppBarComponent:get_height()
  return 1
end

function AppBarComponent:set_default_win_plot(win_plot)
  win_plot.focusable = false
  win_plot.zindex = 5
  win_plot.height = 1

  return self
end

function AppBarComponent:set_default_win_options(win_options)
  win_options.winhl = 'Normal:GitAppBar'
  return self
end

function AppBarComponent:mount()
  if self.mounted then return self end

  local config = self.config
  local win_plot = config.win_plot
  local win_options = config.win_options

  self:set_default_win_plot(win_plot):set_default_win_options(win_options)

  self.notification = Notification()
  self.buffer = Buffer():create():assign_options(config.buf_options)

  local buffer = self.buffer

  self.window = Window:open(buffer, self.plot.win_plot):assign_options(win_options)

  self.mounted = true

  return self
end

function AppBarComponent:unmount()
  self.window:close()
  return self
end

function AppBarComponent:clear_notification()
  if self.buffer:is_valid() then self:clear_extmarks() end
  return self
end

function AppBarComponent:trigger_notification(text)
  self:place_extmark_text({
    text = text,
    hl = 'GitComment',
    row = 0,
    col = 0,
    pos = 'eol',
  })
  return self
end

function AppBarComponent:notify(text)
  self.notification:notify(self, text)
  return self
end

return AppBarComponent
