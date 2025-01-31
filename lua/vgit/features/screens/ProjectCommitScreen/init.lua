local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local SimpleView = require('vgit.ui.views.SimpleView')
local KeyHelpBarView = require('vgit.ui.views.KeyHelpBarView')
local Model = require('vgit.features.screens.ProjectCommitScreen.Model')
local project_commit_preview_setting = require('vgit.settings.project_commit_preview')

local ProjectCommitScreen = Object:extend()

function ProjectCommitScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local model = Model()

  return {
    name = 'Project Commit Screen',
    scene = scene,
    model = model,
    app_bar_view = KeyHelpBarView(scene, {
      keymaps = function()
        local keymaps = project_commit_preview_setting:get('keymaps')
        return { { keymaps['save'] } }
      end,
    }),
    view = SimpleView(scene, {
      title = function()
        return model:get_title()
      end,
      lines = function()
        return model:get_lines()
      end,
    }, { row = 1 }, {
      elements = {
        header = false,
        footer = false,
      },
      buf_options = {
        modifiable = true,
      },
    }),
  }
end

function ProjectCommitScreen:create()
  loop.free_textlock()
  local _, err = self.model:fetch()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.free_textlock()
  self.view:define()
  self.app_bar_view:define()

  self.app_bar_view:mount()
  self.app_bar_view:render()

  self.view:mount()
  self.view:render()
  self.view:set_keymap({
    {
      mode = 'n',
      mapping = project_commit_preview_setting:get('keymaps').save,
      handler = loop.coroutine(function()
        local _, commit_err = self.model:commit(self.view:get_lines())
        loop.free_textlock()

        if commit_err then return console.debug.error(commit_err).error(commit_err) end

        console.info('Successfully committed changes')

        self:destroy()
      end),
    },
  })
  self.view:set_filetype('gitcommit')

  return true
end

function ProjectCommitScreen:destroy()
  self.scene:destroy()
end

return ProjectCommitScreen
