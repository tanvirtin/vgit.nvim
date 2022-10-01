local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local MinimizedView = require('vgit.ui.views.MinimizedView')

local MinimizedScreen = Object:extend()

function MinimizedScreen:constructor()
  local scene = Scene()

  return {
    name = 'Minimized Screen',
    scene = scene,
    view = MinimizedView(scene),
  }
end

function MinimizedScreen:show(_)
  self.view:show({ content = ' ▶ │ Resume last VGit screen' })

  return true
end

function MinimizedScreen:is_focused()
  return self.view:is_focused()
end

function MinimizedScreen:is_mounted()
  return self.view:is_mounted()
end

function MinimizedScreen:destroy()
  self.scene:destroy()

  return self
end

return MinimizedScreen
