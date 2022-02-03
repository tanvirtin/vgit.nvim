local utils = require('vgit.core.utils')
local ComponentPlot = require('vgit.ui.ComponentPlot')
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

local PopupComponent = Component:extend()

function PopupComponent:new(props)
  return setmetatable(
    Component:new(utils.object.assign({
      config = {
        elements = {
          header = false,
          line_number = false,
          footer = false,
        },
      },
    }, props)),
    PopupComponent
  )
end

function PopupComponent:call(callback)
  self.window:call(callback)
  return self
end

function PopupComponent:set_default_win_plot(win_plot)
  win_plot.relative = 'cursor'
  win_plot.border = self:make_border({
    hl = 'GitBorder',
    chars = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
  })
end

function PopupComponent:mount(opts)
  if self.mounted then
    return self
  end
  local config = self.config
  local elements_config = config.elements

  local plot = ComponentPlot
    :new(config.win_plot, utils.object.merge(elements_config, opts))
    :build()

  local win_plot = plot.win_plot
  self:set_default_win_plot(win_plot)

  self.buffer = Buffer:new():create():assign_options(config.buf_options)

  self.window = Window
    :open(self.buffer, win_plot)
    :assign_options(config.win_options)

  self.mounted = true
  self.plot = plot

  return self
end

function PopupComponent:unmount()
  self.window:close()
  return self
end

return PopupComponent
