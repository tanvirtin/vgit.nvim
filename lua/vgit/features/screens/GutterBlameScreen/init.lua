local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local GutterBlameView = require('vgit.ui.views.GutterBlameView')
local Store = require('vgit.features.screens.GutterBlameScreen.Store')

local GutterBlameScreen = Object:extend()

function GutterBlameScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Gutter Blame Screen',
    scene = scene,
    store = store,
    layout_type = 'unified',
    hydrate = false,
    gutter_blame_view = GutterBlameView(scene, store, {
      width = '40vw',
    }, {
      elements = {
        header = false,
      },
    }),
    code_view = CodeView(scene, store, {
      width = '60vw',
      col = '40vw',
    }, {
      elements = {
        header = false,
      },
    }),
  }
end

function GutterBlameScreen:open_commit()
  loop.await_fast_event()
  local lnum = Window(0):get_lnum()
  loop.await_fast_event()
  local err_blames, blames = self.store:get_blames()

  if err_blames then
    return self
  end

  local blame = blames[lnum]

  if not blame.committed then
    return self
  end

  vim.cmd('quit')

  loop.await_fast_event()
  vim.cmd(string.format('VGit project_commits_preview %s', blame.commit_hash))

  return self
end

function GutterBlameScreen:show()
  console.log('Processing blames')

  local buffer = Buffer(0)

  loop.await_fast_event()
  local err = self.store:fetch(buffer.filename, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.gutter_blame_view:show():set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self:open_commit() end),
    },
  })
  self.code_view:show(self.layout_type):set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self:open_commit() end),
    },
  })

  return true
end

function GutterBlameScreen:destroy()
  self.scene:destroy()

  return self
end

return GutterBlameScreen
