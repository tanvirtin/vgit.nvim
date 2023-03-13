local utils = require('vgit.core.utils')
local dimensions = require('vgit.ui.dimensions')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local PresentationalComponent = require('vgit.ui.components.PresentationalComponent')

local SimpleView = Object:extend()

function SimpleView:constructor(scene, store, plot, config)
  return {
    scene = scene,
    store = store,
    plot = plot,
    config = config or {},
  }
end

function SimpleView:get_components() return { self.scene:get('simple_view') } end

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
  return self
end

function SimpleView:set_filetype(filetype)
  self.scene:get('simple_view'):set_filetype(filetype)

  return self
end

function SimpleView:set_keymap(configs)
  utils.list.each(
    configs,
    function(config) self.scene:get('simple_view'):set_keymap(config.mode, config.key, config.handler) end
  )
  return self
end

function SimpleView:set_title()
  if self.config.elements and not self.config.elements.header then
    return self
  end

  local _, title = self.store:get_title()

  self.scene:get('simple_view'):set_title(title)

  return self
end

function SimpleView:get_lines() return self.scene:get('simple_view'):get_lines() end

function SimpleView:render()
  local err, lines = self.store:get_lines()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self:set_title()
  self.scene:get('simple_view'):unlock():set_lines(lines):focus():lock()

  return self
end

function SimpleView:mount(opts)
  self.scene:get('simple_view'):mount(opts)

  return self
end

function SimpleView:show(opts)
  self:mount(opts):render()

  return self
end

return SimpleView
