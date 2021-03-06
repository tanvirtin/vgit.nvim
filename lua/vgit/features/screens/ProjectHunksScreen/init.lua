local fs = require('vgit.core.fs')
local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Query = require('vgit.features.screens.ProjectHunksScreen.Query')

local ProjectHunksScreen = Feature:extend()

function ProjectHunksScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Project Hunks Screen',
    scene = scene,
    query = query,
    layout_type = nil,
    foldable_list_view = FoldableListView(scene, query, {
      height = '30vh',
    }, {
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
            items = utils.list.map(entries, function(entry)
              local id = entry.id
              local mark_index = entry.mark_index
              local git_file = entry.git_file
              local _, hunks = git_file:get_hunks()
              local hunk = hunks[mark_index]

              local list_entry = {
                id = id,
                value = hunk.header,
              }

              return list_entry
            end),
          }
        end

        return foldable_list
      end,
    }),
    code_view = CodeView(scene, query, {
      row = '30vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
  }
end

function ProjectHunksScreen:hunk_up()
  self.code_view:prev()

  return self
end

function ProjectHunksScreen:hunk_down()
  self.code_view:next()

  return self
end

function ProjectHunksScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function ProjectHunksScreen:show(opts)
  opts = opts or {}

  console.log('Processing project hunks')

  local query = self.query
  local layout_type = self.layout_type

  loop.await_fast_event()
  local err = query:fetch(layout_type, opts)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.code_view:show(layout_type)
  self.foldable_list_view:show()

  self.code_view:set_keymap({
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

        Window(0):set_lnum(mark.top_relative):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      vgit_key = 'keys.j',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('down')

        if not list_item then
          return
        end

        query:set_id(list_item.id)
        self.code_view:render_debounced(loop.async(function()
          local _, data = query:get()

          if data then
            self.code_view:navigate_to_mark(data.mark_index)
          end
        end))
      end),
    },
    {
      mode = 'n',
      key = 'k',
      vgit_key = 'keys.k',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('up')

        if not list_item then
          return
        end

        query:set_id(list_item.id)
        self.code_view:render_debounced(loop.async(function()
          local _, data = query:get()

          if data then
            self.code_view:navigate_to_mark(data.mark_index)
          end
        end))
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      vgit_key = 'keys.enter',
      handler = loop.async(function()
        local _, filename = self.query:get_filename()

        if not filename then
          self.foldable_list_view:toggle_current_list_item():render()

          return
        end

        local hunk_err, hunk = query:get_hunk()

        if hunk_err then
          console.error(hunk_err)
          return
        end

        self:destroy()

        fs.open(filename)

        Window(0):set_lnum(hunk.top):position_cursor('center')
      end),
    },
  })
  return true
end

function ProjectHunksScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectHunksScreen
