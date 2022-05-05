local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
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
      height = '80vh',
      width = '100vw',
      row = '20vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    table_view = TableView(scene, query, {
      height = '20vh',
      width = '100vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      column_labels = {
        'Revision',
        'Author Name',
        'Commit Hash',
        'Time',
        'Summary',
      },
      on_row = function(log)
        return {
          log.revision,
          log.author_name or '',
          log.commit_hash or '',
          (log.timestamp and os.date('%Y-%m-%d', tonumber(log.timestamp)))
            or '',
          log.summary or '',
        }
      end,
    }),
  }
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

  self.code_view:set_keymap({
    {
      mode = 'n',
      key = '<C-j>',
      vgit_key = 'keys.Cj',
      handler = loop.async(function()
        self.code_view:next()
      end),
    },
    {
      mode = 'n',
      key = '<C-k>',
      vgit_key = 'keys.Ck',
      handler = loop.async(function()
        self.code_view:prev()
      end),
    },
  })

  -- Set keymap
  self.table_view:set_keymap({
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
    {
      mode = 'n',
      key = '<C-j>',
      vgit_key = 'keys.Cj',
      handler = loop.async(function()
        self.code_view:next()
      end),
    },
    {
      mode = 'n',
      key = '<C-k>',
      vgit_key = 'keys.Ck',
      handler = loop.async(function()
        self.code_view:prev()
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
