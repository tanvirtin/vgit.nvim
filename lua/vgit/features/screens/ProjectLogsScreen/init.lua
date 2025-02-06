local loop = require('vgit.core.loop')
local Scene = require('vgit.ui.Scene')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local TableView = require('vgit.ui.views.TableView')
local PaginationView = require('vgit.ui.views.PaginationView')
local Model = require('vgit.features.screens.ProjectLogsScreen.Model')
local project_logs_preview_setting = require('vgit.settings.project_logs_preview')

local ProjectLogsScreen = Object:extend()

function ProjectLogsScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local model = Model()

  return {
    name = 'Logs Screen',
    scene = scene,
    model = model,
    event_handlers = { on_select = function() end },
    pagination_view = PaginationView(scene, {
      keymaps = function()
        local keymaps = project_logs_preview_setting:get('keymaps')
        return {
          { 'Previous', keymaps['previous'] },
          { 'Next', keymaps['next'] },
        }
      end,
      pagination = function()
        return model:get_pagination()
      end,
    }),
    logs_view = TableView(scene, {
      headers = function()
        return {
          {
            name = 'commit_hash',
            caption = 'Commit',
          },
          {
            name = 'author_name',
            caption = 'Author',
          },
          {
            name = 'timestamp',
            caption = 'Date',
          },
          {
            name = 'summary',
            caption = 'Summary',
          },
        }
      end,
      entries = function()
        return model:get_logs()
      end,
      is_selected = function(entry)
        return model:is_selected(entry)
      end,
    }, { row = 1 }),
  }
end

function ProjectLogsScreen:open()
  local commit_hashes = self.model:get_selected()
  if #commit_hashes == 0 then return end

  vim.cmd(utils.list.reduce(commit_hashes, 'VGit project_commits_preview', function(cmd, log)
    return cmd .. ' ' .. log.commit_hash
  end))
end

function ProjectLogsScreen:previous()
  loop.free_textlock()
  self.model:previous()

  loop.free_textlock()
  self.pagination_view:render()
  self.logs_view:render()
end

function ProjectLogsScreen:next()
  loop.free_textlock()
  self.model:next()

  loop.free_textlock()
  self.pagination_view:render()
  self.logs_view:render()
end

function ProjectLogsScreen:select(entry)
  self.model:select(entry)
end

function ProjectLogsScreen:setup_keymaps()
  local keymaps = project_logs_preview_setting:get('keymaps')

  self.logs_view:set_keymap({
    {
      mode = 'n',
      mapping = keymaps.previous,
      handler = loop.coroutine(function()
        self:previous()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.next,
      handler = loop.coroutine(function()
        self:next()
      end),
    },
    {
      mode = 'n',
      mapping = {
        key = '<enter>',
        desc = 'Open commit(s)',
      },
      handler = loop.coroutine(function()
        self:open()
      end),
    },
  })
end

function ProjectLogsScreen:create()
  loop.free_textlock()
  local _, err = self.model:fetch()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  self.logs_view:define()
  self.pagination_view:define()

  self.pagination_view:mount()
  self.pagination_view:render()

  self.logs_view:mount({
    event_handlers = {
      on_select = function(entry)
        self:select(entry)
      end,
    },
  })
  self.logs_view:render()

  self:setup_keymaps()

  return true
end

function ProjectLogsScreen:destroy()
  self.scene:destroy()
end

return ProjectLogsScreen
