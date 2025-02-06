local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local SimpleSplit = require('vgit.ui.splits.SimpleSplit')
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
    split = SimpleSplit(scene, {
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

function ProjectCommitScreen:save()
  local _, err = self.model:commit(self.split:get_lines())
  loop.free_textlock()
  if err then return console.debug.error(err).error(err) end
  console.info('Successfully committed changes')
  self:destroy()
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
  self.split:define()

  self.split:mount()
  self.split:render()
  self.split:set_filetype('gitcommit')

  self.split:set_keymap({
    {
      mode = 'n',
      mapping = project_commit_preview_setting:get('keymaps').save,
      handler = loop.coroutine(function()
        self:save()
      end),
    },
  })

  return true
end

function ProjectCommitScreen:destroy()
  self.scene:destroy()
end

return ProjectCommitScreen
