local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local AppBarComponent = require('vgit.ui.components.AppBarComponent')

local AppBarView = Object:extend()

function AppBarView:constructor(scene, query, plot)
  return {
    scene = scene,
    query = query,
    plot = plot,
  }
end

function AppBarView:define()
  self.scene:set(
    'footer',
    AppBarComponent({
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

function AppBarView:set_lines(lines)
  self.scene:get('footer'):set_lines(lines)

  return self
end

function AppBarView:mount_scene(mount_opts)
  self.scene:get('footer'):mount(mount_opts)

  return self
end

function AppBarView:show(mount_opts)
  self:define():mount_scene(mount_opts)

  return self
end

return AppBarView
