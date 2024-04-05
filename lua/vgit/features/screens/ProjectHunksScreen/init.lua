local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Store = require('vgit.features.screens.ProjectHunksScreen.Store')

local ProjectHunksScreen = Object:extend()

function ProjectHunksScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'Project Hunks Screen',
    scene = scene,
    store = store,
    layout_type = layout_type,
    foldable_list_view = FoldableListView(scene, store, { height = '30vh' }, {
      elements = {
        header = true,
        footer = false,
      },
      get_list = function(list)
        local foldable_list = {}

        for key in pairs(list) do
          local entries = list[key]

          local icon_before = nil
          local icon, icon_hl = icons.get(key)

          if icon then
            icon_before = {
              icon = icon,
              hl = icon_hl,
            }
          end

          foldable_list[#foldable_list + 1] = {
            open = true,
            value = key,
            icon_before = icon_before,
            items = utils.list.map(
              entries,
              function(entry)
                return {
                  id = entry.id,
                  value = entry.hunk.header,
                }
              end
            ),
          }
        end

        return foldable_list
      end,
    }),
    diff_view = DiffView(scene, store, { row = '30vh' }, {
      elements = {
        header = true,
        footer = false,
      },
    }, layout_type),
  }
end

function ProjectHunksScreen:hunk_up()
  self.diff_view:prev()

  return self
end

function ProjectHunksScreen:hunk_down()
  self.diff_view:next()

  return self
end

function ProjectHunksScreen:handle_list_move(direction)
  local list_item = self.foldable_list_view:move(direction)

  if not list_item then
    return
  end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(loop.coroutine(function()
    local _, data = self.store:get_data()

    if data then
      self.diff_view:navigate_to_mark(data.mark_index)
          end
  end))
end

function ProjectHunksScreen:show(opts)
  opts = opts or {}

  loop.free_textlock()
  local err = self.store:fetch(self.layout_type, opts)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.free_textlock()

  self.diff_view:define()
  self.foldable_list_view:define()

  self.diff_view:show()
  self.foldable_list_view:show()

  self.diff_view:set_keymap({
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local mark = self.diff_view:get_current_mark_under_cursor()

        if not mark then
          return
        end

        local _, filename = self.store:get_filename()

        if not filename then
          return
        end

        self:destroy()

        fs.open(filename)

        Window(0):set_lnum(mark.top_relative):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      handler = loop.coroutine(function() self:handle_list_move('down') end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.coroutine(function() self:handle_list_move('up') end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local _, filename = self.store:get_filename()

        if not filename then
          self.foldable_list_view:toggle_current_list_item():render()
          return
        end

        local data_err, data = self.store:get_data()

        if data_err then
          console.error(data_err)
          return
        end

        self:destroy()

        fs.open(filename)

        Window(0):set_lnum(data.hunk.top):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view.scene:get('list').buffer:on('CursorMoved', loop.coroutine(function() self:handle_list_move() end))

  return true
end

function ProjectHunksScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectHunksScreen
