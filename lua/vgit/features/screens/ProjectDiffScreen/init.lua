local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local Buffer = require('vgit.core.Buffer')
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
  loop.await()
  local current_list_item = self.foldable_list_view:get_current_list_item()
  local metadata = current_list_item.metadata

  if metadata and metadata.category == 'staged' then
    return true
  end

  return false
end

function ProjectDiffScreen:is_current_list_item_unstaged()
  loop.await()
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

ProjectDiffScreen.stage_hunk = loop.debounced_async(function(self)
  if self:is_current_list_item_staged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.await()
  local hunk, index = self.diff_view:get_current_hunk_under_cursor()

  if not hunk then
    return self
  end

  local err = self.mutation:stage_hunk(filename, hunk)

  if err then
    console.debug.error(err)
    return self
  end

  loop.await()
  self.store:fetch(self.layout_type)
  loop.await()

  self.foldable_list_view:evict_cache():render()

  local list_item = self:get_list_item(filename)

  self.store:set_id(list_item.id)

  self.diff_view:render():navigate_to_mark(index)

  return self
end, 15)

ProjectDiffScreen.unstage_hunk = loop.debounced_async(function(self)
  if self:is_current_list_item_unstaged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.await()
  local hunk, index = self.diff_view:get_current_hunk_under_cursor()

  if not hunk then
    return self
  end

  local err = self.mutation:unstage_hunk(filename, hunk)

  if err then
    console.debug.error(err)
    return self
  end

  loop.await()
  self.store:fetch(self.layout_type)
  loop.await()

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

ProjectDiffScreen.stage_file = loop.debounced_async(function(self)
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

ProjectDiffScreen.unstage_file = loop.debounced_async(function(self)
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

ProjectDiffScreen.stage_all = loop.debounced_async(function(self)
  local err = self.mutation:stage_all()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.unstage_all = loop.debounced_async(function(self)
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

ProjectDiffScreen.reset_file = loop.debounced_async(function(self)
  if self:is_current_list_item_staged() then
    return self
  end

  local _, filename = self.store:get_filename()

  if not filename then
    return self
  end

  loop.await()
  local decision =
    console.input(string.format('Are you sure you want to discard changes in %s? (y/N) ', filename)):lower()

  if decision ~= 'yes' and decision ~= 'y' then
    return self
  end

  loop.await()
  local err = self.mutation:reset_file(filename)
  loop.await()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

ProjectDiffScreen.reset_all = loop.debounced_async(function(self)
  loop.await()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then
    return self
  end

  loop.await()
  local err = self.mutation:reset_all()
  loop.await()

  if err then
    console.debug.error(err)
    return self
  end

  return self:render()
end, 15)

function ProjectDiffScreen:render()
  loop.await()
  self.store:fetch(self.layout_type)
  loop.await()

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

function ProjectDiffScreen:show()
  local buffer = Buffer(0)

  loop.await()
  local err = self.store:fetch(self.layout_type)

  if err then
    console.debug.error(err).error(err)
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
      handler = loop.async(function() self:stage_hunk() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_hunk_unstage,
      handler = loop.async(function() self:unstage_hunk() end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function()
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
      handler = loop.async(function() self:commit() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_reset,
      handler = loop.async(function() self:reset_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_stage,
      handler = loop.async(function() self:stage_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').buffer_unstage,
      handler = loop.async(function() self:unstage_file() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').stage_all,
      handler = loop.async(function() self:stage_all() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').unstage_all,
      handler = loop.async(function() self:unstage_all() end),
    },
    {
      mode = 'n',
      key = project_diff_preview_setting:get('keymaps').reset_all,
      handler = loop.async(function() self:reset_all() end),
    },
    {
      mode = 'n',
      key = 'j',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('down')

        self.store:set_id(list_item.id)
        self.diff_view:render_debounced(function() self.diff_view:navigate_to_mark(1) end)
      end),
    },
    {
      mode = 'n',
      key = 'k',
      handler = loop.async(function()
        local list_item = self.foldable_list_view:move('up')

        self.store:set_id(list_item.id)
        self.diff_view:render_debounced(function() self.diff_view:navigate_to_mark(1) end)
      end),
    },
    {
      mode = 'n',
      key = '<enter>',
      handler = loop.async(function()
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

  self:make_help_bar()

  local target_filename = buffer.filename

  if target_filename then
    local list_item = self.foldable_list_view:move_to(function(node)
      -- TODO: This needs a refactor, FSListGenerator
      local filename = node.path and node.path.file and node.path.file.filename or nil
      return filename == target_filename
    end)

    if not list_item then
      list_item = self.foldable_list_view:move_to(function(node)
        local filename = node.path and node.path.file and node.path.file.filename or nil
        return filename ~= nil
      end)
    end

    self.store:set_id(list_item.id)
    self.diff_view:render_debounced(loop.async(function() self.diff_view:navigate_to_mark(1) end))
  end

  return true
end

function ProjectDiffScreen:destroy()
  self.scene:destroy()

  return self
end

return ProjectDiffScreen
