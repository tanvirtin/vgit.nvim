local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local ComponentPlot = require('vgit.ui.ComponentPlot')
local dimensions = require('vgit.ui.dimensions')

local MinimizedComponent = Component:extend()

function MinimizedComponent:constructor(props)
  return utils.object.assign(Component.constructor(self), {
    config = {
      win_plot = { focus = false },
      elements = {
        header = false,
        line_number = false,
        footer = false,
      },
    },
  }, props)
end

function MinimizedComponent:call(callback)
  self.window:call(callback)

  return self
end

function MinimizedComponent:get_height() return 1 end

function MinimizedComponent:set_default_win_plot(win_plot)
  win_plot.focusable = true
  win_plot.zindex = 100
  win_plot.height = 1
  win_plot.row = dimensions.global_height() - 3
  win_plot.border = 'double'

  return self
end

function MinimizedComponent:mount(opts)
  if self.mounted then
    return self
  end

  local config = self.config
  local win_plot = config.win_plot
  local win_options = config.win_options
  local elements_config = config.elements
  local content = opts.content
  local width = #content

  self:set_default_win_plot(win_plot)

  local plot = ComponentPlot(config.win_plot, utils.object.merge(elements_config, opts)):build()

  plot.win_plot.width = width
  plot.win_plot.col = math.floor(dimensions.global_width()) - width

  self.buffer = Buffer():create():assign_options(config.buf_options)
  self.window = Window:open(self.buffer, plot.win_plot):assign_options(win_options)
  self.mounted = true
  self.plot = plot

  self.buffer:set_lines({ opts.content })

  return self
end

function MinimizedComponent:unmount()
  self.mounted = false
  self.window:close()

  return self
end

return MinimizedComponent
