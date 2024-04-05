local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local AppBarView = require('vgit.ui.views.AppBarView')
local FSListGenerator = require('vgit.ui.FSListGenerator')
local FoldableListView = require('vgit.ui.views.FoldableListView')
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
      col = '23vw',
      width = '77vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }, layout_type),
    foldable_list_view = FoldableListView(scene, store, {
      row = 1,
      width = '23vw',
    }, {
      elements = {
        header = false,
        footer = false,
      },
      get_list = function(list)
        if not list then
          return nil
        end

        local foldable_list = {}

        for key in pairs(list) do
          foldable_list[#foldable_list + 1] = {
            open = true,
            show_count = false,
            value = key,
            items = FSListGenerator(list[key]):generate({ category = key }),
          }
        end

        return foldable_list
      end,
    }),
  }
end

function ProjectDiffScreen:hunk_up()
  self.diff_view:prev()

  return self
end

function ProjectDiffScreen:hunk_down()
  self.diff_view:next()

  return self
end

function ProjectDiffScreen:is_current_list_item_staged()
  loop.free_textlock()
  local current_list_item = self.foldable_list_view:get_current_list_item()
  local metadata = current_list_item.metadata

  if metadata and metadata.category == 'staged' then
    return true
  end

  return false
end

function ProjectDiffScreen:is_current_list_item_unstaged()
  loop.free_textlock()
  local current_list_item = self.foldable_list_view:get_current_list_item()
  local metadata = current_list_item.metadata

  if metadata and metadata.category == 'unstaged' then
    return true
  end

  return false
end

function ProjectDiffScreen:get_list_item(filename)
  local query_fn = function(list_item)
    if list_item.items then
      return false
    end

    local metadata = list_item.metadata
    local path = list_item.path
    local file = path.file

    return metadata.category == 'changes' and filename == file.filename and file:is_unstaged()
  end

  return self.foldable_list_view:query_list_item(query_fn) or self.foldable_list_view:get_current_list_item()
end

ProjectDiffScreen.stage_hunk = loop.debounce_coroutine(function(self)
  if self:is_current_list_item_staged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.free_textlock()
  local hunk, index = self.diff_view:get_current_hunk_under_cursor()

  if not hunk then
    return self
  end

  local err = self.mutation:stage_hunk(filename, hunk)

  if err then
    console.debug.error(err)
    return self
  end

  loop.free_textlock()
  self.store:fetch(self.layout_type)
  loop.free_textlock()

  self.foldable_list_view:evict_cache():render()

  local list_item = self:get_list_item(filename)

  self.store:set_id(list_item.id)

  self.diff_view:render():navigate_to_mark(index)

  return self
end, 15)

ProjectDiffScreen.unstage_hunk = loop.debounce_coroutine(function(self)
  if self:is_current_list_item_unstaged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.free_textlock()
  local hunk, index = self.diff_view:get_current_hunk_under_cursor()

  if not hunk then
    return self
  end

  local err = self.mutation:unstage_hunk(filename, hunk)

  if err then
    console.debug.error(err)
    return self
  end

  loop.free_textlock()
  self.store:fetch(self.layout_type)
  loop.free_textlock()

  local list_item = self.foldable_list_view:evict_cache():render():query_list_item(function(list_item)
    if list_item.items then
      return false
    end

    local metadata = list_item.metadata
    local path = list_item.path
    local file = path.file

    return metadata.category == 'staged' and filename == file.filename and file:is_unstaged()
  end) or self.foldable_list_view:get_current_list_item()

  self.store:set_id(list_item.id)

  self.diff_view:render():navigate_to_mark(index)

  return self
end, 15)

ProjectDiffScreen.stage_file = loop.debounce_coroutine(function(self)
  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  local err = self.mutation:stage_file(filename)

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.unstage_file = loop.debounce_coroutine(function(self)
  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  local err = self.mutation:unstage_file(filename)

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.stage_all = loop.debounce_coroutine(function(self)
  local err = self.mutation:stage_all()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.unstage_all = loop.debounce_coroutine(function(self)
  local err = self.mutation:unstage_all()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

function ProjectDiffScreen:commit()
  self:destroy()
  vim.cmd('VGit project_commit_preview')
end

ProjectDiffScreen.reset_file = loop.debounce_coroutine(function(self)
  if self:is_current_list_item_staged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.free_textlock()
  local decision =
    console.input(string.format('Are you sure you want to discard changes in %s? (y/N) ', filename)):lower()

  if decision ~= 'yes' and decision ~= 'y' then
    return self
  end

  loop.free_textlock()
  local err = self.mutation:reset_file(filename)
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.reset_all = loop.debounce_coroutine(function(self)
  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then
    return self
  end

  loop.free_textlock()
  local err = self.mutation:reset_all()
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

function ProjectDiffScreen:render()
  loop.free_textlock()
  local _, data = self.store:fetch(self.layout_type)
  loop.free_textlock()

  if utils.object.is_empty(data) then
    self:destroy()

    return self
  end

  local list_item = self.foldable_list_view:render():get_current_list_item()

  self.store:set_id(list_item.id)

  self.diff_view:render():navigate_to_mark(1)

  return self
end

function ProjectDiffScreen:make_help_bar()
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

  return self
end

function ProjectDiffScreen:handle_list_move(direction)
  local list_item = self.foldable_list_view:move(direction)

  if not list_item then
    return
  end

  self.store:set_id(list_item.id)
  self.diff_view:render_debounced(function() self.diff_view:navigate_to_mark(1) end)
end

function ProjectDiffScreen:show()
  loop.free_textlock()
  local err, data = self.store:fetch(self.layout_type)

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
      handler = loop.coroutine(function() self:stage_hunk() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_hunk_unstage,
      handler = loop.coroutine(function() self:unstage_hunk() end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local mark, _ = self.diff_view:get_current_mark_under_cursor()

        if not mark then
          return
        end

        local _, filename = self.store:get_filename()

        if not filename then
          return
        end

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
      handler = loop.coroutine(function() self:commit() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_reset,
      handler = loop.coroutine(function() self:reset_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_stage,
      handler = loop.coroutine(function() self:stage_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_unstage,
      handler = loop.coroutine(function() self:unstage_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').stage_all,
      handler = loop.coroutine(function() self:stage_all() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').unstage_all,
      handler = loop.coroutine(function() self:unstage_all() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').reset_all,
      handler = loop.coroutine(function() self:reset_all() end),
    },
    {
      mode = 'n',
      key = 'j',
      handler = loop.coroutine(function() self:handle_list_move('down') end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.coroutine(function() self:handle_list_move('up') end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.coroutine(function()
        local _, filename = self.store:get_filename()

        if not filename then
          self.foldable_list_view:toggle_current_list_item():render()

          return self
        end

        self:destroy()

        fs.open(filename)

        local diff_dto_err, diff_dto = self.store:get_diff_dto()

        if diff_dto_err or not diff_dto then
          return
        end

        Window(0):set_lnum(diff_dto.marks[1].top_relative):position_cursor('center')
      end),
    },
  })

  self.foldable_list_view.scene:get('list').buffer:on('CursorMoved', loop.coroutine(function() self:handle_list_move() end))

  self:make_help_bar()

  local list_item = self.foldable_list_view:move_to(function(node)
    local filename = node.path and node.path.file and node.path.file.filename or nil
    return filename ~= nil
  end)

  if list_item then
    self.store:set_id(list_item.id)
    self.diff_view:render_debounced(loop.coroutine(function() self.diff_view:navigate_to_mark(1) end))
  end

  return true
end

function ProjectDiffScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectDiffScreen
