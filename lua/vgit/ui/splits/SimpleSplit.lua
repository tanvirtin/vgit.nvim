local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local Split = require('vgit.ui.Split')
local dimensions = require('vgit.ui.dimensions')

local SimpleSplit = Object:extend()

function SimpleSplit:constructor(scene, props, plot, config)
  return {
    plot = plot,
    scene = scene,
    props = props,
    config = config or {},
  }
end

function SimpleSplit:get_components()
  return { self.scene:get('simple_split') }
end

function SimpleSplit:define()
  self.scene:set(
    'simple_split',
    Split({
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

function SimpleSplit:on(event_name, callback)
  self.scene:get('simple_split'):on(event_name, callback)
end

function SimpleSplit:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene:get('simple_split'):set_keymap(config, config.handler)
  end)
end

function SimpleSplit:set_filetype(filetype)
  self.scene:get('simple_split'):set_filetype(filetype)
end

function SimpleSplit:get_lines()
  return self.scene:get('simple_split'):get_lines()
end

function SimpleSplit:mount(opts)
  self.scene:get('simple_split'):mount(opts)
end

function SimpleSplit:render()
  local lines = self.props.lines()
  if not lines then return end

  self.scene:get('simple_split'):unlock():set_lines(lines):lock()
end

return SimpleSplit
