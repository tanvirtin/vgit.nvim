local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local LineBlameView = require('vgit.ui.views.LineBlameView')
local Query = require('vgit.features.screens.LineBlameScreen.Query')

local LineBlameScreen = Feature:extend()

function LineBlameScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Line Blame Screen',
    scene = scene,
    query = query,
    line_blame_view = LineBlameView(scene, query, {
      relative = 'cursor',
      height = 6,
    }, {
      elements = {
        header = false,
      },
    }),
  }
end

function LineBlameScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function LineBlameScreen:show()
  console.log('Processing line blame')

  local query = self.query
  local buffer = Buffer(0)
  local window = Window(0)

  loop.await_fast_event()
  local err = query:fetch(buffer.filename, window:get_lnum())

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.line_blame_view:show({ winline = vim.fn.winline() + 1 })

  return true
end

function LineBlameScreen:destroy()
  self.scene:destroy()

  return self
end

return LineBlameScreen
