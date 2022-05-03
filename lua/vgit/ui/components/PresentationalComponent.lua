local ComponentPlot = require('vgit.ui.ComponentPlot')
local utils = require('vgit.core.utils')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

local PresentationalComponent = Component:extend()

function PresentationalComponent:constructor(props)
  return utils.object.assign(Component.constructor(self), {
    config = {
      elements = {
        header = true,
        footer = true,
        line_number = false,
      },
    },
  }, props)
end

function PresentationalComponent:call(callback)
  self.window:call(callback)

  return self
end

function PresentationalComponent:mount(opts)
  if self.mounted then
    return self
  end

  opts = opts or {}
  local config = self.config
  local elements_config = config.elements

  local win_plot = config.win_plot

  local plot = ComponentPlot(
    win_plot,
    utils.object.merge(elements_config, opts)
  ):build()

  local buffer = Buffer():create():assign_options(config.buf_options)
  self.buffer = buffer

  self.window = Window:open(buffer, win_plot):assign_options(config.win_options)

  if elements_config.header then
    self.elements.header = HeaderElement():mount(plot.header_win_plot)
  end

  if elements_config.footer then
    self.elements.footer = FooterElement():mount(plot.footer_win_plot)
  end

  self.mounted = true
  self.plot = plot

  return self
end

function PresentationalComponent:unmount()
  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()

  if header then
    header:unmount()
  end

  if footer then
    footer:unmount()
  end

  return self
end

function PresentationalComponent:set_title(text)
  local header = self.elements.header

  if header then
    header:set_lines({ text })
  end

  return self
end

return PresentationalComponent
