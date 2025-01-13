local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Model = require('vgit.features.screens.ProjectStashScreen.Model')

local ProjectStashScreen = Object:extend()

function ProjectStashScreen:constructor()
  local scene = Scene()
  local model = Model()

  return {
    name = 'Stash Screen',
    scene = scene,
    model = model,
    view = GitLogsView(scene, {
      logs = function()
        return model:get_logs()
      end,
    }),
  }
end

function ProjectStashScreen:create(opts)
  loop.free_textlock()
  local _, err = self.model:fetch(opts)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.view:define()
  self.view:mount()
  self.view:render()
  self.view:set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      handler = loop.coroutine(function()
        self.view:select()
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        if not self.view:has_selection() then self.view:select() end
        vim.cmd('quit')
        vim.cmd(utils.list.reduce(self.view:get_selected(), 'VGit project_commits_preview', function(cmd, log)
          return cmd .. ' ' .. log.commit_hash
        end))
      end),
    },
  })

  return true
end

function ProjectStashScreen:destroy()
  self.scene:destroy()
end

return ProjectStashScreen
