local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local AppBarView = require('vgit.ui.views.AppBarView')
local FoldableListView = require('vgit.ui.views.FoldableListView')
local StatusListGenerator = require('vgit.ui.StatusListGenerator')
local Store = require('vgit.features.screens.ProjectDiffScreen.Store')
local Mutation = require('vgit.features.screens.ProjectDiffScreen.Mutation')
local project_diff_preview_setting = require('vgit.settings.project_diff_preview')

local ProjectDiffScreen = Object:extend()

function ProjectDiffScreen:constructor(opts)
  opts = opts or {}
  local scene = Scene()
  local store = Store()
  local mutation = Mutation()
  local layout_type = opts.layout_type or 'unified'

  return {
    name = 'Project Diff Screen',
    scene = scene,
    store = store,
    mutation = mutation,
    layout_type = layout_type,
    app_bar_view = AppBarView(scene, store),
    diff_view = DiffView(scene, store, {
      row = 1,
      col = '20vw',
      width = '80vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }, layout_type),
    foldable_list_view = FoldableListView(scene, store, {
      row = 1,
      width = '20vw',
    }, {
      elements = {
        header = false,
        footer = false,
      },
      get_list = function(list)
        if not list then return nil end

        local foldable_list = {}
        -- NOTE: category here will either be Changes, Staged Changes, Unmerged Changes
        for category in pairs(list) do
          local entry = list[category]
          foldable_list[#foldable_list + 1] = {
            open = true,
            value = category,
            items = StatusListGenerator(entry):generate({ category = category }),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectDiffScreen:hunk_up()
  self.diff_view:prev()
end

function ProjectDiffScreen:hunk_down()
  self.diff_view:next()
end

function ProjectDiffScreen:move_to(query_fn)
  local list_item = self.foldable_list_view:move_to(query_fn)
  if not list_item then return end

  self.store:set_id(list_item.id)
  self.diff_view:render():navigate_to_mark(1)

  return list_item
end

ProjectDiffScreen.stage_hunk = loop.debounce_coroutine(function(self)
  local entry = self.store:get()
  if not entry then return end
  if entry.type ~= 'unstaged' then return end

  loop.free_textlock()
  local hunk = self.diff_view:get_current_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local _, err = self.mutation:stage_hunk(filename, hunk)
  if err then
    console.debug.error(err)
    return
  end

  self:render()
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    local category = node.metadata and node.metadata.category or nil
    return node_filename == entry.status.filename and category == 'Changes'
  end)
end, 5)

ProjectDiffScreen.unstage_hunk = loop.debounce_coroutine(function(self)
  local entry = self.store:get()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local hunk = self.diff_view:get_current_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local _, err = self.mutation:unstage_hunk(filename, hunk)
  if err then
    console.debug.error(err)
    return
  end

  self:render()
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    local category = node.metadata and node.metadata.category or nil
    return node_filename == entry.status.filename and category == 'Staged Changes'
  end)
end, 5)

ProjectDiffScreen.stage_file = loop.debounce_coroutine(function(self)
  local entry = self.store:get()
  if not entry then return end
  if entry.type ~= 'unstaged' and entry.type ~= 'unmerged' then return end

  loop.free_textlock()
  local filename = entry.status.filename
  local _, err = self.mutation:stage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render()
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    return node_filename == entry.status.filename
  end)
end, 15)

ProjectDiffScreen.unstage_file = loop.debounce_coroutine(function(self)
  local entry = self.store:get()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local filename = entry.status.filename
  local _, err = self.mutation:unstage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render()
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    return node_filename == entry.status.filename
  end)
end, 15)

ProjectDiffScreen.stage_all = loop.debounce_coroutine(function(self)
  local _, err = self.mutation:stage_all()
  if err then
    console.debug.error(err)
    return
  end

  local entry = self.store:get()
  self:render()
  if not entry then return end
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    return node_filename == entry.status.filename
  end)
end, 15)

ProjectDiffScreen.unstage_all = loop.debounce_coroutine(function(self)
  local _, err = self.mutation:unstage_all()
  if err then
    console.debug.error(err)
    return
  end

  local entry = self.store:get()
  self:render()
  if not entry then return end
  self:move_to(function(node)
    local node_filename = node.path and node.path.status and node.path.status.filename or nil
    return node_filename == entry.status.filename
  end)
end, 15)

function ProjectDiffScreen:commit()
  self:destroy()
  vim.cmd('VGit project_commit_preview')
end

ProjectDiffScreen.reset_file = loop.debounce_coroutine(function(self)
  local filename = self.store:get_filename()
  if not filename then return end

  loop.free_textlock()
  local decision =
    console.input(string.format('Are you sure you want to discard changes in %s? (y/N) ', filename)):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local _, err = self.mutation:reset_file(filename)
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return
  end

  self:render()
end, 15)

ProjectDiffScreen.reset_all = loop.debounce_coroutine(function(self)
  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local _, err = self.mutation:reset_all()
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return
  end

  self:render()
end, 15)

function ProjectDiffScreen:render()
  local data = self.store:fetch(self.layout_type)
  loop.free_textlock()

  if utils.object.is_empty(data) then return self:destroy() end

  local list_item = self.foldable_list_view:render():get_current_list_item()
  self.store:set_id(list_item.id)

  self.diff_view:render():navigate_to_mark(1)
end

function ProjectDiffScreen:render_help_bar()
  local text = ''
  local keymaps = project_diff_preview_setting:get('keymaps')
  local keys = {
    'buffer_stage',
    'buffer_unstage',
    'buffer_hunk_stage',
    'buffer_hunk_unstage',
    'buffer_reset',
    'stage_all',
    'unstage_all',
    'reset_all',
    'commit',
  }
  local translations = {
    'Stage',
    'Unstage',
    'Stage hunk',
    'Unstage hunk',
    'Reset',
    'Stage all',
    'Unstage all',
    'Reset all',
    'Commit',
  }

  for i = 1, #keys do
    text = i == 1 and string.format('%s (%s)', translations[i], keymaps[keys[i]])
      or string.format('%s | %s (%s)', text, translations[i], keymaps[keys[i]])
  end

  self.app_bar_view:set_lines({ text })
  self.app_bar_view:add_pattern_highlight('%((%a+)%)', 'Keyword')
  self.app_bar_view:add_pattern_highlight('|', 'Number')
end

function ProjectDiffScreen:handle_list_move(direction)
  local list_item = self.foldable_list_view:move(direction)

  if not list_item then return end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(function()
    self.diff_view:navigate_to_mark(1)
  end)
end

function ProjectDiffScreen:show()
  local data, err = self.store:fetch(self.layout_type)
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  if utils.object.is_empty(data) then
    console.info('No changes found')
    return false
  end

  self.app_bar_view:define()
  self.diff_view:define()
  self.foldable_list_view:define()

  self.app_bar_view:show()
  self.diff_view:show()
  self.foldable_list_view:show()

  self.diff_view:set_keymap({
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_hunk_stage,
      handler = loop.coroutine(function()
        self:stage_hunk()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_hunk_unstage,
      handler = loop.coroutine(function()
        self:unstage_hunk()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_reset,
      handler = loop.coroutine(function()
        self:reset_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_stage,
      handler = loop.coroutine(function()
        self:stage_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_unstage,
      handler = loop.coroutine(function()
        self:unstage_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').stage_all,
      handler = loop.coroutine(function()
        self:stage_all()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').unstage_all,
      handler = loop.coroutine(function()
        self:unstage_all()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').reset_all,
      handler = loop.coroutine(function()
        self:reset_all()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').commit,
      handler = loop.coroutine(function()
        self:commit()
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local mark, _ = self.diff_view:get_current_mark_under_cursor()
        if not mark then return end

        local filename = self.store:get_filename()
        if not filename then return end

        self:destroy()

        fs.open(filename)

        Window(0):set_lnum(mark.top_relative):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view:set_keymap({
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').commit,
      handler = loop.coroutine(function()
        self:commit()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_reset,
      handler = loop.coroutine(function()
        self:reset_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_stage,
      handler = loop.coroutine(function()
        self:stage_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_unstage,
      handler = loop.coroutine(function()
        self:unstage_file()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').stage_all,
      handler = loop.coroutine(function()
        self:stage_all()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').unstage_all,
      handler = loop.coroutine(function()
        self:unstage_all()
      end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').reset_all,
      handler = loop.coroutine(function()
        self:reset_all()
      end),
    },
    {
      mode = 'n',
      key = 'j',
      handler = loop.coroutine(function()
        self:handle_list_move('down')
      end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.coroutine(function()
        self:handle_list_move('up')
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local filename = self.store:get_filename()
        if not filename then
          self.foldable_list_view:toggle_current_list_item()
          self.foldable_list_view:render()
          return
        end

        self:destroy()
        fs.open(filename)

        local diff, diff_err = self.store:get_diff()
        if diff_err or not diff then return end

        local mark = diff.marks[1]
        if not mark then return end

        Window(0):set_lnum(mark.top_relative):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view.scene:get('list').buffer:on(
    'CursorMoved',
    loop.coroutine(function()
      self:handle_list_move()
    end)
  )

  self:render_help_bar()

  self:move_to(function(node)
    local filename = node.path and node.path.status and node.path.status.filename or nil
    return filename ~= nil
  end)

  return true
end

function ProjectDiffScreen:destroy()
  self.scene:destroy()
end

return ProjectDiffScreen
