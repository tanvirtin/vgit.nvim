local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local AppBarComponent = require('vgit.ui.components.AppBarComponent')

local AppBarView = Object:extend()

function AppBarView:constructor(scene, store, plot)
  return {
    scene = scene,
    store = store,
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

function AppBarView:get_components() return { self.scene:get('footer') } end

function AppBarView:set_lines(lines)
  self.scene:get('footer'):set_lines(lines)

  return self
end

function AppBarView:mount(opts)
  self.scene:get('footer'):mount(opts)

  return self
end

function AppBarView:show(opts)
  self:mount(opts)

  return self
end

return AppBarView
