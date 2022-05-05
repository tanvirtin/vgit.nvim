local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local HeaderComponent = require('vgit.ui.components.HeaderComponent')

local HeaderView = Object:extend()

function HeaderView:constructor(scene, query, plot)
  return {
    scene = scene,
    query = query,
    plot = plot,
  }
end

function HeaderView:define()
  self.scene:set(
    'header',
    HeaderComponent({
      config = {
        win_plot = dimensions.relative_win_plot(self.plot, {
          height = '100vh',
          width = '100vw',
        }),
      },
    })
  )

  return self
end

function HeaderView:mount_scene(mount_opts)
  self.scene:get('header'):mount(mount_opts)

  return self
end

function HeaderView:show(mount_opts)
  self:define():mount_scene(mount_opts)

  return self
end

return HeaderView
