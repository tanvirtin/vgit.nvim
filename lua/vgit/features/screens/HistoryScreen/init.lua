local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Buffer = require('vgit.core.Buffer')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local BlameListView = require('vgit.ui.views.BlameListView')
local Model = require('vgit.features.screens.HistoryScreen.Model')

local HistoryScreen = Object:extend()

function HistoryScreen:constructor(opts)
  opts = opts or {}

  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'History Screen',
    scene = scene,
    model = model,
    diff_view = DiffView(scene, {
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
    }, {
      row = '20vh',
      height = '100vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    blame_list_view = BlameListView(scene, {
      config = function()
        return model:get_config()
      end,
      entries = function()
        return model:get_entries()
      end,
    }, { height = '20vh' }, {
      elements = {
        header = false,
        footer = false,
      },
    }),
  }
end

function HistoryScreen:hunk_up()
  self.diff_view:prev()
end

function HistoryScreen:hunk_down()
  self.diff_view:next()
end

HistoryScreen.render_diff_view_debounced = loop.debounce_coroutine(function(self)
  self.diff_view:render()
  self.diff_view:move_to_hunk()
end, 200)

function HistoryScreen:handle_list_move(lnum)
  self.model:set_entry_index(lnum)
  self:render_diff_view_debounced()
end

function HistoryScreen:handle_list_enter(buffer, row)
  vim.cmd('quit')

  loop.free_textlock()
  vim.cmd(string.format('VGit project_commits_preview --filename=%s %s', buffer:get_name(), row.commit_hash))
end

function HistoryScreen:create()
  local buffer = Buffer(0)
  local _, err = self.model:fetch(buffer:get_name())
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.diff_view:define()
  self.blame_list_view:define()

  self.diff_view:mount()
  self.blame_list_view:mount({
    event_handlers = {
      on_enter = function(row)
        self:handle_list_enter(buffer, row)
      end,
      on_move = function(lnum)
        self:handle_list_move(lnum)
      end,
    },
  })

  self.blame_list_view:render()

  return true
end

function HistoryScreen:destroy()
  self.scene:destroy()
end

return HistoryScreen
