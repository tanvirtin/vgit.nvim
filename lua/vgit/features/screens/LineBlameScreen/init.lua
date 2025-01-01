local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local RowLayout = require('vgit.ui.RowLayout')
local DiffView = require('vgit.ui.views.DiffView')
local LineBlameView = require('vgit.ui.views.LineBlameView')
local Model = require('vgit.features.screens.LineBlameScreen.Model')

local LineBlameScreen = Object:extend()

function LineBlameScreen:constructor(opts)
  opts = opts or {}

  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'Line Blame Screen',
    scene = scene,
    model = model,
    diff_view = DiffView(
      scene,
      {
        layout_type = function()
          return model:get_layout_type()
        end,
        filename = function()
          return model:get_filename()
        end,
        filetype = function()
          return model:get_filetype()
        end,
        diff = function()
          return model:get_diff()
        end,
      },
      { relative = 'cursor', height = '35vh' },
      { elements = { header = true, footer = true } }
    ),
    line_blame_view = LineBlameView(
      scene,
      { blame = function() return model:get_blame() end },
      { relative = 'cursor', height = 5 },
      { elements = { header = false } }
    ),
  }
end

function LineBlameScreen:hunk_up()
  self.diff_view:prev()
end

function LineBlameScreen:hunk_down()
  self.diff_view:next()
end

function LineBlameScreen:handle_on_enter(buffer, blame)
  vim.cmd('quit')

  local filename = buffer:get_name()
  vim.cmd(string.format('VGit project_commits_preview --filename=%s %s', filename, blame.commit_hash))
end

function LineBlameScreen:create()
  local buffer = Buffer(0)
  local window = Window(0)

  local lnum = window:get_lnum()
  local filename = buffer:get_name()
  local blame, err = self.model:fetch(filename, lnum)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.line_blame_view:define()
  self.diff_view:define()
  RowLayout(self.line_blame_view, self.diff_view):build()

  self.line_blame_view:mount()
  self.diff_view:mount()

  self.line_blame_view:render()
  self.diff_view:render()

  self.line_blame_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        self:handle_on_enter(buffer, blame)
      end),
    },
  })
  self.diff_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        self:handle_on_enter(buffer, blame)
      end),
    },
  })
  self.diff_view:set_relative_lnum(blame.lnum)

  return true
end

function LineBlameScreen:destroy()
  self.scene:destroy()
end

return LineBlameScreen
