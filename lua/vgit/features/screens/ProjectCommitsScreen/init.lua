local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local CodeView = require('vgit.ui.views.CodeView')
local FSListGenerator = require('vgit.ui.FSListGenerator')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local Store = require('vgit.features.screens.ProjectCommitsScreen.Store')

local ProjectCommitsScreen = Object:extend()

function ProjectCommitsScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Project Commits Screen',
    scene = scene,
    store = store,
    hydrate = false,
    layout_type = nil,
    code_view = CodeView(scene, store, {
      col = '25vw',
      width = '75vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    foldable_list_view = FoldableListView(scene, store, {
      width = '25vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
      get_list = function(commits)
        if utils.object.size(commits) == 1 then
          return FSListGenerator(utils.object.first(commits)):generate()
        end

        local foldable_list = {}

        for commit_hash, files in pairs(commits) do
          foldable_list[#foldable_list + 1] = {
            open = true,
            value = commit_hash:sub(1, 8),
            items = FSListGenerator(files):generate(),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectCommitsScreen:get_list_title(commits)
  return utils.object.size(commits) == 1 and utils.object.first(commits):sub(1, 8) or 'Project commits'
end

function ProjectCommitsScreen:hunk_up()
  self.code_view:prev()

  return self
end

function ProjectCommitsScreen:hunk_down()
  self.code_view:next()

  return self
end

function ProjectCommitsScreen:show(commits)
  console.log('Processing project commits')

  loop.await()
  local err = self.store:fetch(self.layout_type, commits, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await()
  self.code_view:show(self.layout_type)
  self.foldable_list_view:set_title(self:get_list_title(commits)):show()

  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = 'j',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('down')

        if not list_item then
          return
        end

        self.store:set_id(list_item.id)
        self.code_view:render_debounced(loop.async(function() self.code_view:navigate_to_mark(1) end))
      end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('up')

        if not list_item then
          return
        end

        self.store:set_id(list_item.id)
        self.code_view:render_debounced(function() self.code_view:navigate_to_mark(1) end)
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self.foldable_list_view:toggle_current_list_item():render() end),
    },
  })
  return true
end

function ProjectCommitsScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectCommitsScreen
