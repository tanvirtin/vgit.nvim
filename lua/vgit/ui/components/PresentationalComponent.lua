local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')

local PresentationalComponent = Component:extend()

function PresentationalComponent:constructor(props)
  props = utils.object.assign({
    config = {
      elements = {
        header = true,
        footer = true,
      },
    },
  }, props)
  return Component.constructor(self, props)
end

function PresentationalComponent:call(callback)
  self.window:call(callback)
  return self
end

function PresentationalComponent:mount(opts)
  if self.mounted then return self end

  opts = opts or {}
  local config = self.config

  local win_plot = config.win_plot
  local plot = self.plot

  local buffer = Buffer():create():assign_options(config.buf_options)
  self.buffer = buffer

  self.window = Window:open(buffer, win_plot):assign_options(config.win_options)

  if config.elements.header then self.elements.header = HeaderElement():mount(plot.header_win_plot) end
  if config.elements.footer then self.elements.footer = FooterElement():mount(plot.footer_win_plot) end

  self.mounted = true

  return self
end

function PresentationalComponent:unmount()
  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()

  if header then header:unmount() end
  if footer then footer:unmount() end

  return self
end

function PresentationalComponent:set_title(text)
  local header = self.elements.header
  if header then header:set_lines({ text }) end

  return self
end

return PresentationalComponent
