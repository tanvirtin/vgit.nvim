local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local utils = require('vgit.core.utils')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local TableView = require('vgit.ui.views.TableView')
local Query = require('vgit.features.screens.HistoryScreen.Query')

local HistoryScreen = Feature:extend()

function HistoryScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'History Screen',
    scene = scene,
    query = query,
    layout_type = nil,
    code_view = CodeView(scene, query, {
      height = '70vh',
      row = '30vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    table_view = TableView(scene, query, {
      height = '30vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      column_labels = {
        'Revision',
        'Author Name',
        'Commit',
        'Date',
        'Summary',
      },
      get_row = function(log)
        local timestamp = log.timestamp

        return {
          log.revision,
          log.author_name or '',
          log.commit_hash:sub(1, 8) or '',
          utils.time.format(timestamp),
          log.summary or '',
        }
      end,
    }),
  }
end

function HistoryScreen:hunk_up()
  self.code_view:prev()

  return self
end

function HistoryScreen:hunk_down()
  self.code_view:next()

  return self
end

function HistoryScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function HistoryScreen:show()
  console.log('Processing history')

  local query = self.query
  local layout_type = self.layout_type
  local buffer = Buffer(0)
  local err = query:fetch(layout_type, buffer.filename)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  -- Show and bind data (data will have all the necessary shape required)
  self.code_view:show(layout_type)
  self.table_view:show()

  -- Set keymap
  self.table_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      vgit_key = 'keys.enter',
      handler = loop.async(function()
        loop.await_fast_event()
        local row = self.table_view:get_current_row()

        if not row then
          return
        end

        vim.cmd('quit')

        loop.await_fast_event()
        vim.cmd(
          string.format('VGit project_commits_preview %s', row.commit_hash)
        )
      end),
    },
    {
      mode = 'n',
      key = 'j',
      vgit_key = 'keys.j',
      handler = loop.async(function()
        query:set_index(self.table_view:move('down'))
        self.code_view:render_debounced(function()
          self.code_view:navigate_to_mark(1)
        end)
      end),
    },
    {
      mode = 'n',
      key = 'k',
      vgit_key = 'keys.k',
      handler = loop.async(function()
        query:set_index(self.table_view:move('up'))
        self.code_view:render_debounced(function()
          self.code_view:navigate_to_mark(1)
        end)
      end),
    },
  })

  return true
end

function HistoryScreen:destroy()
  self.scene:destroy()

  return self
end

return HistoryScreen
