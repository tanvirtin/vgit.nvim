local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Buffer = require('vgit.core.Buffer')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local RowLayout = require('vgit.ui.RowLayout')
local DiffView = require('vgit.ui.views.DiffView')
local TableView = require('vgit.ui.views.TableView')
local Store = require('vgit.features.screens.HistoryScreen.Store')

local HistoryScreen = Object:extend()

function HistoryScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'History Screen',
    scene = scene,
    store = store,
    layout_type = layout_type,
    table_view = TableView(scene, store, { height = '20vh' }, {
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
          log.commit_hash or '',
          utils.date.format(timestamp),
          log.summary or '',
        }
      end,
    }),
    diff_view = DiffView(scene, store, { height = '80vh' }, {
      elements = {
        header = true,
        footer = false,
      },
    }, layout_type),
  }
end

function HistoryScreen:hunk_up()
  self.diff_view:prev()

  return self
end

function HistoryScreen:hunk_down()
  self.diff_view:next()

  return self
end

function HistoryScreen:handle_list_move(direction)
  self.store:set_index(self.table_view:move(direction))
  self.diff_view:render_debounced(function()
    self.diff_view:navigate_to_mark(1)
  end)
end

function HistoryScreen:show()
  local buffer = Buffer(0)
  local err = self.store:fetch(self.layout_type, buffer:get_name())

  loop.free_textlock()
  if err then
    console.debug.error(err).error(err)
    return false
  end

  -- Show and bind data (data will have all the necessary shape required)
  self.diff_view:define()
  self.table_view:define()

  RowLayout(self.diff_view, self.table_view):build()

  self.diff_view:show()
  self.table_view:show()

  -- Set keymap
  self.table_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        loop.free_textlock()
        local row = self.table_view:get_current_row()

        if not row then return end

        vim.cmd('quit')

        loop.free_textlock()
        vim.cmd(string.format('VGit project_commits_preview --filename=%s %s', buffer:get_name(), row.commit_hash))
      end),
    },
    {
      mode = 'n',
      key = 'j',
      handler = loop.coroutine(function()
        self:handle_list_move('down')
      end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.coroutine(function()
        self:handle_list_move('up')
      end),
    },
  })

  self.table_view.scene:get('table').buffer:on(
    'CursorMoved',
    loop.coroutine(function()
      self:handle_list_move()
    end)
  )

  return true
end

function HistoryScreen:destroy()
  self.scene:destroy()

  return self
end

return HistoryScreen
