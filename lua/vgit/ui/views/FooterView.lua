local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local FooterComponent = require('vgit.ui.components.FooterComponent')

local FooterView = Object:extend()

function FooterView:constructor(scene, query, plot)
  return {
    scene = scene,
    query = query,
    plot = plot,
  }
end

function FooterView:define()
  self.scene:set(
    'footer',
    FooterComponent({
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

function FooterView:set_lines(lines)
  self.scene:get('footer'):set_lines(lines)

  return self
end

function FooterView:mount_scene(mount_opts)
  self.scene:get('footer'):mount(mount_opts)

  return self
end

function FooterView:show(mount_opts)
  self:define():mount_scene(mount_opts)

  return self
end

return FooterView
