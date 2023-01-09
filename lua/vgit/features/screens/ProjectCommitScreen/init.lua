local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local SimpleView = require('vgit.ui.views.SimpleView')
local AppBarView = require('vgit.ui.views.AppBarView')
local Store = require('vgit.features.screens.ProjectCommitScreen.Store')
local Mutation = require('vgit.features.screens.ProjectCommitScreen.Mutation')
local project_commit_preview_setting = require('vgit.settings.project_commit_preview')

local ProjectCommitScreen = Object:extend()

function ProjectCommitScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local mutation = Mutation()

  return {
    name = 'Project Commit Screen',
    scene = scene,
    store = store,
    mutation = mutation,
    app_bar_view = AppBarView(scene, store),
    view = SimpleView(scene, store, { row = 1 }, {
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

function ProjectCommitScreen:make_help_bar()
  local text = ''
  local keymaps = project_commit_preview_setting:get('keymaps')
  local keys = { 'save' }
  local translations = { 'Save commit' }

  for i = 1, #keys do
    text = i == 1 and string.format('%s (%s)', translations[i], keymaps[keys[i]])
      or string.format('%s | %s (%s)', text, translations[i], keymaps[keys[i]])
  end

  self.app_bar_view:set_lines({ text })
  self.app_bar_view:add_pattern_highlight('%((%a+)%)', 'Keyword')
  self.app_bar_view:add_pattern_highlight('|', 'Number')

  return self
end

function ProjectCommitScreen:show()
  loop.await()
  local err = self.store:fetch()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  loop.await()
  self.view:define()
  self.app_bar_view:define()

  self.app_bar_view:show()
  self:make_help_bar()

  self.view:show()
  self.view:set_keymap({
    {
      mode = 'n',
      key = project_commit_preview_setting:get('keymaps').save,
      handler = loop.async(function()
        local commit_err = self.mutation:commit(self.view:get_lines())
        loop.await()

        if commit_err then
          return console.debug.error(commit_err).error(commit_err)
        end

        console.info('Successfully committed changes')

        self:destroy()
      end),
    },
  })

  return true
end

function ProjectCommitScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectCommitScreen
