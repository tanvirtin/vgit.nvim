local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local GutterBlameView = require('vgit.ui.views.GutterBlameView')
local Store = require('vgit.features.screens.GutterBlameScreen.Store')

local GutterBlameScreen = Object:extend()

function GutterBlameScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()

  return {
    name = 'Gutter Blame Screen',
    scene = scene,
    store = store,
    layout_type = 'unified',
    gutter_blame_view = GutterBlameView(scene, store, { width = '40vw' }, { elements = { header = false } }),
    diff_view = DiffView(scene, store, { width = '60vw', col = '40vw' }, { elements = { header = false } }, 'unified'),
  }
end

function GutterBlameScreen:open_commit()
  loop.await()
  local lnum = Window(0):get_lnum()
  loop.await()
  local err_blames, blames = self.store:get_blames()

  if err_blames then
    return self
  end

  local blame = blames[lnum]

  if not blame.committed then
    return self
  end

  vim.cmd('quit')

  loop.await()
  vim.cmd(string.format('VGit project_commits_preview %s', blame.commit_hash))

  return self
end

function GutterBlameScreen:show()
  local buffer = Buffer(0)

  loop.await()
  local err = self.store:fetch(buffer.filename, buffer:get_lines())

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.gutter_blame_view:define()
  self.diff_view:define()

  self.gutter_blame_view:show()
  self.gutter_blame_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self:open_commit() end),
    },
  })
  self.diff_view:show()
  self.diff_view:set_keymap({
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
