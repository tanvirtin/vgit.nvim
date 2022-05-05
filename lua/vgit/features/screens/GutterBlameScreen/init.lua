local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local GutterBlameView = require('vgit.ui.views.GutterBlameView')
local Query = require('vgit.features.screens.GutterBlameScreen.Query')

local GutterBlameScreen = Feature:extend()

function GutterBlameScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Gutter Blame Screen',
    scene = scene,
    query = query,
    layout_type = 'unified',
    gutter_blame_view = GutterBlameView(scene, query, {
      height = '100vh',
      width = '40vw',
    }, {
      elements = {
        header = false,
      },
    }),
    code_view = CodeView(scene, query, {
      height = '100vh',
      width = '60vw',
      col = '40vw',
    }, {
      elements = {
        header = false,
      },
    }),
  }
end

function GutterBlameScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function GutterBlameScreen:show()
  console.log('Processing blames')

  local query = self.query
  local layout_type = self.layout_type
  local buffer = Buffer(0)

  loop.await_fast_event()
  local err = query:fetch(buffer.filename)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.gutter_blame_view:show()
  self.code_view:show(layout_type)

  return true
end

function GutterBlameScreen:destroy()
  self.scene:destroy()

  return self
end

return GutterBlameScreen
