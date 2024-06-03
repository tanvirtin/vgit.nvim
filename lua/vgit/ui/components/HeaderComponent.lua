local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local Namespace = require('vgit.core.Namespace')
local HeaderTitle = require('vgit.ui.decorations.HeaderTitle')
local Notification = require('vgit.ui.decorations.Notification')

local HeaderComponent = Component:extend()

function HeaderComponent:constructor(props)
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

function HeaderComponent:call(callback)
  self.window:call(callback)

  return self
end

function HeaderComponent:get_height()
  return 1
end

function HeaderComponent:set_default_win_plot(win_plot)
  win_plot.focusable = false
  win_plot.zindex = 3
  win_plot.height = 1

  return self
end

function HeaderComponent:set_default_win_options(win_options)
  win_options.winhl = 'Normal:GitHeader'

  return self
end

function HeaderComponent:mount()
  if self.mounted then return self end

  local config = self.config
  local win_plot = config.win_plot
  local win_options = config.win_options

  self:set_default_win_plot(win_plot):set_default_win_options(win_options)

  self.notification = Notification()
  self.header_title = HeaderTitle()
  self.namespace = Namespace()
  self.buffer = Buffer():create():assign_options(config.buf_options)

  local buffer = self.buffer

  self.window = Window:open(buffer, self.plot.win_plot):assign_options(win_options)

  self.mounted = true

  return self
end

function HeaderComponent:unmount()
  self.window:close()

  return self
end

function HeaderComponent:clear_title()
  self.header_title:clear(self)

  return self
end

function HeaderComponent:set_title(title, opts)
  self.header_title:set(self, title, opts)

  return self
end

function HeaderComponent:clear_notification()
  if self.buffer:is_valid() then self.namespace:clear(self.buffer) end

  return self
end

function HeaderComponent:trigger_notification(text)
  self.namespace:transpose_virtual_text(self.buffer, {
    text = text,
    hl = 'GitComment',
    row = 0,
    col = 0,
    pos = 'eol',
  })

  return self
end

function HeaderComponent:notify(text)
  self.notification:notify(self, text)

  return self
end

return HeaderComponent
