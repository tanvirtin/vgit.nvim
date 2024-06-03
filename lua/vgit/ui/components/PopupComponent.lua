local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')

local PopupComponent = Component:extend()

function PopupComponent:constructor(props)
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

function PopupComponent:call(callback)
  self.window:call(callback)

  return self
end

function PopupComponent:set_default_win_plot(win_plot)
  win_plot.relative = 'cursor'
  win_plot.border = self:render_border({
    hl = 'GitBorder',
    chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  })

  return self
end

function PopupComponent:mount()
  if self.mounted then return self end

  local config = self.config

  local win_plot = self.plot.win_plot

  self:set_default_win_plot(win_plot)

  self.buffer = Buffer():create():assign_options(config.buf_options)

  self.window = Window:open(self.buffer, win_plot):assign_options(config.win_options)

  self.mounted = true

  return self
end

function PopupComponent:unmount()
  self.window:close()

  return self
end

return PopupComponent
