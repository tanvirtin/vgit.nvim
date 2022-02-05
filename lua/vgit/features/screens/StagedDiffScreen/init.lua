local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local Query = require('vgit.features.screens.StagedDiffScreen.Query')

local StagedDiffScreen = Feature:extend()

function StagedDiffScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Staged Diff Screen',
    scene = scene,
    query = query,
    layout_type = nil,
    code_view = CodeView(scene, query, {
      height = '100vh',
      width = '100vw',
      row = '0vh',
      col = '0vw',
    }),
  }
end

function StagedDiffScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function StagedDiffScreen:show()
  console.log('Processing diff')

  local query = self.query
  local layout_type = self.layout_type
  local buffer = Buffer(0)

  loop.await_fast_event()
  local err = query:fetch(layout_type, buffer.filename)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.code_view
    :show(layout_type, 'center', { winline = vim.fn.winline() })
    :set_keymap({
      {
        mode = 'n',
        key = '<C-j>',
        vgit_key = 'keys.Cj',
        handler = loop.async(function()
          self.code_view:next('center')
        end),
      },
      {
        mode = 'n',
        key = '<C-k>',
        vgit_key = 'keys.Ck',
        handler = loop.async(function()
          self.code_view:prev('center')
        end),
      },
      {
        mode = 'n',
        key = '<enter>',
        vgit_key = 'keys.enter',
        handler = loop.async(function()
          local mark = self.code_view:get_current_mark_under_cursor()

          if not mark then
            return
          end

          local _, filename = self.query:get_filename()

          if not filename then
            return
          end

          self:destroy()

          fs.open(filename)

          Window(0):set_lnum(mark.top_relative):call(function()
            vim.cmd('norm! zz')
          end)
        end),
      },
    })

  return true
end

function StagedDiffScreen:destroy()
  self.scene:destroy()

  return self
end

return StagedDiffScreen
