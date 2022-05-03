local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local console = require('vgit.core.console')
local SimpleView = require('vgit.ui.views.SimpleView')
local Feature = require('vgit.Feature')
local Query = require('vgit.features.screens.DebugScreen.Query')

local DebugScreen = Feature:extend()

function DebugScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Debug Screen',
    scene = scene,
    query = query,
    view = SimpleView(scene, query, {
      height = '100vh',
      width = '100vw',
      row = '0vh',
      col = '0vw',
    }),
  }
end

function DebugScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function DebugScreen:show(source)
  console.log('Processing info')

  local query = self.query

  loop.await_fast_event()
  local err = query:fetch(source)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.view:show()

  return true
end

function DebugScreen:destroy()
  self.scene:destroy()

  return self
end

return DebugScreen
