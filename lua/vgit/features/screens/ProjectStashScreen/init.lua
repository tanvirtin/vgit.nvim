local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local StatusListView = require('vgit.ui.views.StatusListView')
local KeymapHelpBarView = require('vgit.ui.views.KeymapHelpBarView')
local Model = require('vgit.features.screens.ProjectStashScreen.Model')
local project_stash_preview_setting = require('vgit.settings.project_stash_preview')

local ProjectStashScreen = Object:extend()

function ProjectStashScreen:constructor(opts)
  opts = opts or {}

  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'Stash Screen',
    scene = scene,
    model = model,
    app_bar_view = KeymapHelpBarView(scene, {
      keymaps = function()
        local keymaps = project_stash_preview_setting:get('keymaps')
        return {
          { 'Add', keymaps['add'] },
          { 'Apply', keymaps['apply'] },
          { 'Pop', keymaps['pop'] },
          { 'Drop', keymaps['drop'] },
          { 'Clear', keymaps['clear'] },
        }
      end,
    }),
    status_list_view = StatusListView(scene, {
      entries = function()
        return model:get_entries()
      end,
    }, {
      row = 1,
      height = '20vh'
    }, {
      elements = {
        header = false,
        footer = false,
      },
      open_folds = false,
    }),
    diff_view = DiffView(scene, {
      layout_type = function()
        return model:get_layout_type()
      end,
      filename = function()
        return model:get_filename()
      end,
      filetype = function()
        return model:get_filetype()
      end,
      diff = function()
        return model:get_diff()
      end,
    }, {
      row = '20vh',
      height = '100vh',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
  }
end

function ProjectStashScreen:handle_list_move(direction)
  local list_item = self.status_list_view:move(direction)
  if not list_item then return end

  self.model:set_entry_id(list_item.id)
  self.diff_view:render()
  self.diff_view:move_to_hunk()
end

function ProjectStashScreen:render()
  local entries = self.model:fetch()
  loop.free_textlock()

  if utils.object.is_empty(entries) then return self:destroy() end

  self.status_list_view:render()

  local list_item = self.status_list_view:get_current_list_item()
  self.model:set_entry_id(list_item.id)

  self.diff_view:render()
  self.diff_view:move_to_hunk()
end

function ProjectStashScreen:add()
  local _, err = self.model:add()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return
  end

  self:render()
end

function ProjectStashScreen:apply(stash_index)
  local _, err = self.model:apply(stash_index)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return
  end

  console.info('Stash ' .. stash_index .. ' applied')
  self:render()
end

function ProjectStashScreen:pop(stash_index)
  loop.free_textlock()
  local decision = console.input('Are you sure you want to pop ' .. stash_index .. '? (y/N) '):lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  local _, err = self.model:pop(stash_index)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return
  end

  self:render()
end

function ProjectStashScreen:drop(stash_index)
  loop.free_textlock()
  local decision = console.input('Are you sure you want to pop ' .. stash_index .. '? (y/N) '):lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  local _, err = self.model:drop(stash_index)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return
  end

  self:render()
end

function ProjectStashScreen:clear()
  loop.free_textlock()
  local decision = console.input('Are you sure you want to clear all your stash? (y/N) '):lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  local _, err = self.model:clear()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return
  end

  self:render()
end

function ProjectStashScreen:create(opts)
  loop.free_textlock()
  local _, err = self.model:fetch(opts)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.diff_view:define()
  self.app_bar_view:define()
  self.status_list_view:define()

  self.diff_view:mount()
  self.app_bar_view:mount()
  self.status_list_view:mount({
    event_handlers = {
      on_move = function()
        self:handle_list_move()
      end,
    },
  })

  self.app_bar_view:render()
  self.status_list_view:render()
  self.diff_view:render()

  self.status_list_view:set_keymap({
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').add,
      handler = loop.coroutine(function()
        self:add()
      end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').apply,
      handler = loop.coroutine(function()
        local list_item = self.status_list_view:get_current_list_item()
        if not list_item then return end

        if list_item.items then
          local stash_index = string.match(list_item.value, "stash@%b{}")
          if stash_index then self:apply(stash_index) end
        end
      end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').pop,
      handler = loop.coroutine(function()
        local list_item = self.status_list_view:get_current_list_item()
        if not list_item then return end

        if list_item.items then
          local stash_index = string.match(list_item.value, "stash@%b{}")
          if stash_index then self:pop(stash_index) end
        end
      end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').drop,
      handler = loop.coroutine(function()
        local list_item = self.status_list_view:get_current_list_item()
        if not list_item then return end

        if list_item.items then
          local stash_index = string.match(list_item.value, "stash@%b{}")
          if stash_index then self:drop(stash_index) end
        end
      end),
    },
    {
      mode = 'n',
      key = project_stash_preview_setting:get('keymaps').clear,
      handler = loop.coroutine(function()
        self:clear()
      end),
    },
  })

  return true
end

function ProjectStashScreen:destroy()
  self.scene:destroy()
end

return ProjectStashScreen
