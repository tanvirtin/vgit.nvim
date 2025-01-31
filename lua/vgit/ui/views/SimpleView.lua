local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local SimpleView = Object:extend()

function SimpleView:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    config = config or {},
  }
end

function SimpleView:get_components()
  return { self.scene:get('simple_view') }
end

function SimpleView:define()
  self.scene:set(
    'simple_view',
    PresentationalComponent({
      config = {
        elements = utils.object.assign({ header = true, footer = false }, self.config.elements),
        buf_options = utils.object.assign({ modifiable = true }, self.config.buf_options),
        win_options = {
          cursorbind = true,
          scrollbind = true,
          cursorline = true,
        },
        win_plot = dimensions.relative_win_plot(self.plot, {
          height = '100vh',
          width = '100vw',
        }),
      },
    })
  )
end

function SimpleView:set_filetype(filetype)
  self.scene:get('simple_view'):set_filetype(filetype)
end

function SimpleView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene:get('simple_view'):set_keymap(config, config.handler)
  end)
end

function SimpleView:set_title()
  if self.config.elements and not self.config.elements.header then return end

  local title = self.props.title()
  self.scene:get('simple_view'):set_title(title)
end

function SimpleView:get_lines()
  return self.scene:get('simple_view'):get_lines()
end

function SimpleView:mount(opts)
  self.scene:get('simple_view'):mount(opts)
end

function SimpleView:render()
  local lines = self.props.lines()
  if not lines then return end

  self:set_title()
  self.scene:get('simple_view'):unlock():set_lines(lines):lock()
end

return SimpleView
