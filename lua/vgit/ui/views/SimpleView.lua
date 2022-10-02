local utils = require('vgit.core.utils')
local dimensions = require('vgit.ui.dimensions')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local PresentationalComponent = require(
  'vgit.ui.components.PresentationalComponent'
)

local SimpleView = Object:extend()

function SimpleView:constructor(scene, query, plot, config)
  return {
    scene = scene,
    query = query,
    plot = plot,
    config = config or {},
  }
end

function SimpleView:define()
  self.scene:set(
    'simple_view',
    PresentationalComponent({
      config = {
        elements = utils.object.assign({
          header = true,
          footer = false,
        }, self.config.elements),
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

function SimpleView:set_keymap(configs)
  utils.list.each(configs, function(config)
    self.scene
      :get('simple_view')
      :set_keymap(config.mode, config.key, config.handler)
  end)
  return self
end

function SimpleView:set_title()
  local _, title = self.query:get_title()

  self.scene:get('simple_view'):set_title(title)

  return self
end

function SimpleView:render()
  local err, lines = self.query:get_lines()

  if err then
    console.debug.error(err).error(err)
    return self
  end

  self:set_title()
  self.scene:get('simple_view'):unlock():set_lines(lines):focus():lock()

  return self
end

function SimpleView:mount_scene(mount_opts)
  self.scene:get('simple_view'):mount(mount_opts)

  return self
end

function SimpleView:show(mount_opts)
  self:define():mount_scene(mount_opts):render()

  return self
end

return SimpleView
