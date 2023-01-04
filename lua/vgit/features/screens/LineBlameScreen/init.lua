local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local LineBlameView = require('vgit.ui.views.LineBlameView')
local Store = require('vgit.features.screens.LineBlameScreen.Store')

local LineBlameScreen = Object:extend()

function LineBlameScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Line Blame Screen',
    scene = scene,
    store = store,
    line_blame_view = LineBlameView(scene, store, {
      relative = 'cursor',
      height = 6,
    }, {
      elements = {
        header = false,
      },
    }),
  }
end

function LineBlameScreen:show()
  local buffer = Buffer(0)
  local window = Window(0)

  loop.await()
  local err = self.store:fetch(buffer.filename, window:get_lnum())

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await()
  self.line_blame_view:show({ winline = vim.fn.winline() + 1 })

  return true
end

function LineBlameScreen:destroy()
  self.scene:destroy()

  return self
end

return LineBlameScreen
