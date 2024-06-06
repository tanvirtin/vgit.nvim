local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Store = require('vgit.features.screens.ProjectStashScreen.Store')

local ProjectStashScreen = Object:extend()

function ProjectStashScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Stash Screen',
    scene = scene,
    store = store,
    view = GitLogsView(scene, store),
  }
end

function ProjectStashScreen:show(opts)
  loop.free_textlock()
  local _, err = self.store:fetch(opts)

  loop.free_textlock()
  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.view:define()
  self.view:show()
  self.view:set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      handler = loop.coroutine(function()
        loop.free_textlock()

        self.view:select()
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local view = self.view

        if not view:has_selection() then view:select() end

        vim.cmd('quit')

        loop.free_textlock()
        vim.cmd(utils.list.reduce(view:get_selected(), 'VGit project_commits_preview', function(cmd, log)
          return cmd .. ' ' .. log.commit_hash
        end))
      end),
    },
  })

  return true
end

function ProjectStashScreen:destroy()
  self.scene:destroy()
  return self
end

return ProjectStashScreen
