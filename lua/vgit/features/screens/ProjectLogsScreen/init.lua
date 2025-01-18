local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Model = require('vgit.features.screens.ProjectLogsScreen.Model')

local ProjectLogsScreen = Object:extend()

function ProjectLogsScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local model = Model()

  return {
    name = 'Logs Screen',
    scene = scene,
    model = model,
    view = GitLogsView(scene, {
      logs = function()
        return model:get_logs()
      end,
    }),
  }
end

function ProjectLogsScreen:create()
  loop.free_textlock()
  local logs, err = self.model:fetch()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  if not logs or #logs == 0 then
    console.info('No stash found')
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

function ProjectLogsScreen:destroy()
  self.scene:destroy()
end

return ProjectLogsScreen
