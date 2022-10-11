local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local SimpleView = require('vgit.ui.views.SimpleView')
local Store = require('vgit.features.screens.DebugScreen.Store')

local DebugScreen = Object:extend()

function DebugScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Debug Screen',
    hydrate = false,
    scene = scene,
    store = store,
    view = SimpleView(scene, store),
  }
end

function DebugScreen:show(source)
  local allowed_sources = { 'infos', 'warnings', 'errors' }

  if not utils.list.find(allowed_sources, function(s) return s == source end) then
    return
  end

  loop.await()
  local err = self.store:fetch(source, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await()
  self.view:show()

  return true
end

function DebugScreen:destroy()
  self.scene:destroy()

  return self
end

return DebugScreen
