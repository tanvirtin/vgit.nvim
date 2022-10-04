local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Buffer = require('vgit.core.Buffer')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local TableView = require('vgit.ui.views.TableView')
local Store = require('vgit.features.screens.HistoryScreen.Store')

local HistoryScreen = Object:extend()

function HistoryScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'History Screen',
    scene = scene,
    store = store,
    hydrate = false,
    layout_type = nil,
    table_view = TableView(scene, store, {
      height = '30vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      column_labels = {
        'Author Name',
        'Commit',
        'Date',
        'Summary',
      },
      get_row = function(log)
        local timestamp = log.timestamp

        return {
          log.author_name or '',
          log.commit_hash:sub(1, 8) or '',
          utils.date.format(timestamp),
          log.summary or '',
        }
      end,
    }),
    code_view = CodeView(scene, store, {
      row = '30vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
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

function HistoryScreen:show()
  console.log('Processing history')

  local buffer = Buffer(0)
  local err = self.store:fetch(self.layout_type, buffer.filename, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  -- Show and bind data (data will have all the necessary shape required)
  self.code_view:show(self.layout_type)
  self.table_view:show()

  -- Set keymap
  self.table_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function()
        loop.await()
        local row = self.table_view:get_current_row()

        if not row then
          return
        end

        vim.cmd('quit')

        loop.await()
        vim.cmd(string.format('VGit project_commits_preview %s', row.commit_hash))
      end),
    },
    {
      mode = 'n',
      key = 'j',
      handler = loop.async(function()
        self.store:set_index(self.table_view:move('down'))
        self.code_view:render_debounced(function() self.code_view:navigate_to_mark(1) end)
      end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.async(function()
        self.store:set_index(self.table_view:move('up'))
        self.code_view:render_debounced(function() self.code_view:navigate_to_mark(1) end)
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
