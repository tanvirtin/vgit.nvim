local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Feature = require('vgit.Feature')
local utils = require('vgit.core.utils')
local console = require('vgit.core.console')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Query = require('vgit.features.screens.ProjectStashScreen.Query')

local ProjectStashScreen = Feature:extend()

function ProjectStashScreen:constructor()
  local scene = Scene()
  local query = Query()

  return {
    name = 'Stash Screen',
    scene = scene,
    query = query,
    view = GitLogsView(scene, query),
  }
end

function ProjectStashScreen:trigger_keypress(key, ...)
  self.scene:trigger_keypress(key, ...)

  return self
end

function ProjectStashScreen:show(options)
  console.log('Processing logs')

  local query = self.query

  loop.await_fast_event()
  local err = query:fetch(options)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await_fast_event()
  self.view:show():set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      vgit_key = 'keys.tab',
      handler = loop.async(function()
        loop.await_fast_event()

        self.view:select()
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      vgit_key = 'keys.enter',
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

function ProjectStashScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectStashScreen
