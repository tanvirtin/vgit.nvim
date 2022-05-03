local loop = require('vgit.core.loop')
local icons = require('vgit.core.icons')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local utils = require('vgit.core.utils')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Query = require('vgit.features.screens.ProjectCommitsScreen.Query')

local ProjectCommitsScreen = Feature:extend()

function ProjectCommitsScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Project Commits Screen',
    scene = scene,
    query = query,
    layout_type = nil,
    code_view = CodeView(scene, query, {
      height = '80vh',
      width = '100vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    foldable_list_view = FoldableListView(scene, query, {
      row = '80vh',
      height = '20vh',
      width = '100vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      get_list = function(list)
        local foldable_list = {}

        for key in pairs(list) do
          local entries = list[key]

          foldable_list[#foldable_list + 1] = {
            open = true,
            value = key,
            items = utils.list.map(entries, function(entry)
              local file = entry.file
              local filename = file.filename
              local icon, icon_hl = icons.file_icon(filename, file.filetype)

              local list_entry = {
                id = entry.id,
                value = filename,
              }

              if icon then
                list_entry.icon_before = {
                  icon = icon,
                  hl = icon_hl,
                }
              end

              return list_entry
            end),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectCommitsScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function ProjectCommitsScreen:show(commits)
  console.log('Processing project commits')

  local query = self.query
  local layout_type = self.layout_type

  loop.await_fast_event()
  local err = query:fetch(layout_type, commits)

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

  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      vgit_key = 'keys.j',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('down')

        query:set_id(list_item.id)
        self.code_view:render_debounced(loop.async(function()
          self.code_view:navigate_to_mark(1)
        end))
      end),
    },
    {
      mode = 'n',
      key = 'k',
      vgit_key = 'keys.k',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('up')

        query:set_id(list_item.id)
        self.code_view:render_debounced(function()
          self.code_view:navigate_to_mark(1)
        end)
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      vgit_key = 'keys.enter',
      handler = loop.async(function()
        self.foldable_list_view:toggle_current_list_item():render()
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

function ProjectCommitsScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectCommitsScreen
