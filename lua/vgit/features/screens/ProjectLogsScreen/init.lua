local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local utils = require('vgit.core.utils')
local console = require('vgit.core.console')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Store = require('vgit.features.screens.ProjectLogsScreen.Store')

local ProjectLogsScreen = Object:extend()

function ProjectLogsScreen:constructor()
  local scene = Scene()
  local store = Store()

  return {
    name = 'Logs Screen',
    hydrate = false,
    scene = scene,
    store = store,
    view = GitLogsView(scene, store),
  }
end

function ProjectLogsScreen:show(options)
  console.log('Processing logs')

  loop.await_fast_event()
  local err = self.store:fetch(options, { hydrate = self.hydrate })

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.view:show():set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      handler = loop.async(function()
        loop.await_fast_event()

        self.view:select()
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function()
        local view = self.view

        if not view:has_selection() then
          view:select()
        end

        vim.cmd('quit')

        loop.await_fast_event()
        vim.cmd(
          utils.list.reduce(
            view:get_selected(),
            'VGit project_commits_preview',
            function(cmd, log)
              return cmd .. ' ' .. log.commit_hash
            end
          )
        )
      end),
    },
  })

  return true
end

function ProjectLogsScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectLogsScreen
