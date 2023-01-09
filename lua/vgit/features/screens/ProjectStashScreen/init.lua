local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local AppBarView = require('vgit.ui.views.AppBarView')
local GitLogsView = require('vgit.ui.views.GitLogsView')
local Store = require('vgit.features.screens.ProjectStashScreen.Store')
local Mutation = require('vgit.features.screens.ProjectStashScreen.Mutation')
local project_stash_preview_setting = require('vgit.settings.project_stash_preview')

local ProjectStashScreen = Object:extend()

function ProjectStashScreen:constructor()
  local scene = Scene()
  local store = Store()
  local mutation = Mutation()

  return {
    name = 'Stash Screen',
    scene = scene,
    store = store,
    mutation = mutation,
    app_bar_view = AppBarView(scene, store),
    view = GitLogsView(scene, store, { row = 1 }),
  }
end

function ProjectStashScreen:make_help_bar()
  local text = ''
  local keymaps = project_stash_preview_setting:get('keymaps')
  local keys = {
    'apply',
    'pop',
    'drop',
    'clear',
  }
  local translations = {
    'Apply',
    'Pop',
    'Drop',
    'Clear',
  }

  for i = 1, #keys do
    text = i == 1 and string.format('%s (%s)', translations[i], keymaps[keys[i]])
      or string.format('%s | %s (%s)', text, translations[i], keymaps[keys[i]])
  end

  self.app_bar_view:set_lines({ text })
  self.app_bar_view:add_pattern_highlight('%((%a+)%)', 'Keyword')
  self.app_bar_view:add_pattern_highlight('|', 'Number')

  return self
end

function ProjectStashScreen:handle_select()
  loop.await()

  self.view:select()
end

function ProjectStashScreen:handle_on_enter()
  local view = self.view

  if not view:has_selection() then
    view:select()
  end

  self:destroy()

  loop.await()
  vim.cmd(
    utils.list.reduce(
      view:get_selected(),
      'VGit project_commits_preview',
      function(cmd, log) return cmd .. ' ' .. log.commit_hash end
    )
  )
end

function ProjectStashScreen:handle_stash_apply()
  local lnum = Window(0):get_lnum()
  local index = lnum - 1

  loop.await()
  local stash_apply_err, output = self.mutation:stash_apply(index)

  if stash_apply_err then
    loop.await()
    console.debug.error(stash_apply_err).error(stash_apply_err)
    return
  end

  console.info(output)
end

function ProjectStashScreen:handle_stash_pop(opts)
  local lnum = Window(0):get_lnum()
  local index = lnum - 1

  loop.await()
  local stash_apply_err, output = self.mutation:stash_pop(index)

  if stash_apply_err then
    loop.await()
    console.debug.error(stash_apply_err).error(stash_apply_err)
    return
  end

  loop.await()
  local refetch_err = self.store:fetch(opts)
  loop.await()

  console.info(output)

  if refetch_err then
    if refetch_err[1] == 'No stashes found' then
      self:destroy()
      return
    end

    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.view:render()
end

function ProjectStashScreen:handle_stash_drop(opts)
  local lnum = Window(0):get_lnum()
  local index = lnum - 1

  loop.await()
  local stash_apply_err, output = self.mutation:stash_drop(index)

  if stash_apply_err then
    loop.await()
    console.debug.error(stash_apply_err).error(stash_apply_err)
    return
  end

  loop.await()
  local refetch_err = self.store:fetch(opts)
  loop.await()

  console.info(output)

  if refetch_err then
    if refetch_err[1] == 'No stashes found' then
      self:destroy()
      return
    end

    console.debug.error(refetch_err).error(refetch_err)
    return
  end

  self.view:render()
end

function ProjectStashScreen:handle_stash_clear()
  loop.await()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then
    return
  end

  loop.await()
  local stash_clear_err, output = self.mutation:stash_clear()
  loop.await()

  if stash_clear_err then
    console.debug.error(stash_clear_err).error(stash_clear_err)
    return
  end

  console.info(output)

  self:destroy()
end

function ProjectStashScreen:show(opts)
  loop.await()
  local err = self.store:fetch(opts)

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.app_bar_view:define()
  self.view:define()

  self.app_bar_view:show()
  self.view:show()
  self.view:set_keymap({
    {
      mode = 'n',
      key = '<tab>',
      handler = loop.async(function() self:handle_select() end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function() self:handle_on_enter() end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').apply,
      handler = loop.async(function() self:handle_stash_apply() end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').pop,
      handler = loop.async(function() self:handle_stash_pop(opts) end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').drop,
      handler = loop.async(function() self:handle_stash_drop(opts) end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').clear,
      handler = loop.async(function() self:handle_stash_clear() end),
    },
  })

  self:make_help_bar()

  return true
end

function ProjectStashScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectStashScreen
