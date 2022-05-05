local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local Feature = require('vgit.Feature')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local Query = require('vgit.features.screens.DiffScreen.Query')

local DiffScreen = Feature:extend()

function DiffScreen:create_code_view(scene, query, opts)
  if opts.is_hunk then
    return CodeView(scene, query, {
      relative = 'cursor',
      height = '35vh',
      width = '100vw',
    }, {
      elements = {
        header = true,
        footer = true,
      },
    })
  end

  return CodeView(scene, query, {
    height = '100vh',
    width = '100vw',
  })
end

function DiffScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local query = Query()

  return {
    name = 'Diff Screen',
    scene = scene,
    query = query,
    layout_type = nil,
    code_view = DiffScreen:create_code_view(scene, query, opts),
  }
end

function DiffScreen:hunk_up()
  self.code_view:prev('center')

  return self
end

function DiffScreen:hunk_down()
  self.code_view:next('center')

  return self
end

function DiffScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function DiffScreen:show(opts)
  console.log('Processing diff')

  local query = self.query
  local layout_type = self.layout_type
  local buffer = Buffer(0)

  loop.await_fast_event()
  local err = query:fetch(layout_type, buffer.filename, opts)

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

function DiffScreen:destroy()
  self.scene:destroy()

  return self
end

return DiffScreen