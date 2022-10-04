local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local HeaderComponent = require('vgit.ui.components.HeaderComponent')

local HeaderView = Object:extend()

function HeaderView:constructor(scene, store, plot)
  return {
    scene = scene,
    store = store,
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

function HeaderView:mount(opts)
  self.scene:get('header'):mount(opts)

  return self
end

function HeaderView:show(opts)
  self:define():mount(opts)

  return self
end

return HeaderView
