local Object = require('vgit.core.Object')
local dimensions = require('vgit.ui.dimensions')
local MinimizedComponent = require('vgit.ui.components.MinimizedComponent')

local MinimizedView = Object:extend()

function MinimizedView:constructor(scene, store, plot)
  return {
    scene = scene,
    store = store,
    plot = plot,
  }
end

function MinimizedView:define()
  self.scene:set(
    'minimized_view',
    MinimizedComponent({
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

function MinimizedView:set_lines(lines)
  self.scene:get('minimized_view'):set_lines(lines, true)

  return self
end

function MinimizedView:is_focused() return self.scene:get('minimized_view'):is_focused() end

function MinimizedView:is_mounted()
  local component = self.scene:get('minimized_view')
  return component and component.mounted or false
end

function MinimizedView:mount(opts)
  self.scene:get('minimized_view'):mount(opts)

  return self
end

function MinimizedView:show(opts)
  self:define():mount(opts)

  return self
end

return MinimizedView
