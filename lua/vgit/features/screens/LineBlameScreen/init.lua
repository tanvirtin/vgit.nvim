local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local RowLayout = require('vgit.ui.RowLayout')
local DiffView = require('vgit.ui.views.DiffView')
local LineBlameView = require('vgit.ui.views.LineBlameView')
local Store = require('vgit.features.screens.LineBlameScreen.Store')

local LineBlameScreen = Object:extend()

function LineBlameScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'Line Blame Screen',
    layout_type = layout_type,
    scene = scene,
    store = store,
    diff_view = DiffView(
      scene,
      store,
      { relative = 'cursor', height = '35vh' },
      { elements = { header = true, footer = true } },
      layout_type
    ),
    line_blame_view = LineBlameView(
      scene,
      store,
      { relative = 'cursor', height = 5 },
      { elements = { header = false } }
    ),
  }
end

function LineBlameScreen:hunk_up()
  self.diff_view:prev()

  return self
end

function LineBlameScreen:hunk_down()
  self.diff_view:next()

  return self
end

function LineBlameScreen:handle_on_enter(buffer, blame)
  vim.cmd('quit')

  loop.free_textlock()
  vim.cmd(string.format('VGit project_commits_preview --filename=%s %s', buffer.filename, blame.commit_hash))
end

function LineBlameScreen:show()
  local buffer = Buffer(0)
  local window = Window(0)

  loop.free_textlock()
  local lnum = window:get_lnum()
  local filename = buffer.filename
  local layout_type = self.layout_type
  local err = self.store:fetch(layout_type, filename, lnum)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.line_blame_view:define()
  self.diff_view:define()

  RowLayout(self.line_blame_view, self.diff_view):build()

  self.line_blame_view:show()
  self.diff_view:show()

  local blame_err, blame = self.store:get_blame()

  if blame_err then
    return true
  end

  self.diff_view:set_relative_lnum(blame.lnum)
  self.diff_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function() self:handle_on_enter(buffer, blame) end),
    },
  })
  self.line_blame_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function() self:handle_on_enter(buffer, blame) end),
    },
  })

  return true
end

function LineBlameScreen:destroy()
  self.scene:destroy()

  return self
end

return LineBlameScreen
