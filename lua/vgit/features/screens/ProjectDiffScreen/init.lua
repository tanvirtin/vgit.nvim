local fs = require('vgit.core.fs')
local Scene = require('vgit.ui.Scene')
local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Buffer = require('vgit.core.Buffer')
local Object = require('vgit.core.Object')
local Window = require('vgit.core.Window')
local console = require('vgit.core.console')
local DiffView = require('vgit.ui.views.DiffView')
local StatusListView = require('vgit.ui.views.StatusListView')
local KeyHelpBarView = require('vgit.ui.views.KeyHelpBarView')
local Model = require('vgit.features.screens.ProjectDiffScreen.Model')
local project_diff_preview_setting = require('vgit.settings.project_diff_preview')

local ProjectDiffScreen = Object:extend()

function ProjectDiffScreen:constructor(opts)
  opts = opts or {}

  local scene = Scene()
  local model = Model(opts)

  return {
    name = 'Project Diff Screen',
    scene = scene,
    model = model,
    diff_keymaps = {}, -- Store debounced diff keymap handlers for cleanup
    app_bar_view = KeyHelpBarView(scene, {
      keymaps = function()
        local keymaps = project_diff_preview_setting:get('keymaps')
        return {
          { 'Stage',        keymaps['buffer_stage'] },
          { 'Unstage',      keymaps['buffer_unstage'] },
          { 'Reset',        keymaps['buffer_reset'] },
          { 'Stage hunk',   keymaps['buffer_hunk_stage'] },
          { 'Unstage hunk', keymaps['buffer_hunk_unstage'] },
          { 'Reset hunk',   keymaps['buffer_hunk_reset'] },
          { 'Stage all',    keymaps['stage_all'] },
          { 'Unstage all',  keymaps['unstage_all'] },
          { 'Reset all',    keymaps['reset_all'] },
          { 'Commit',       keymaps['commit'] },
        }
      end,
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
      row = 1,
      col = '25vw',
      width = '75vw',
    }, {
      elements = {
        header = true,
        footer = false,
      },
    }),
    status_list_view = StatusListView(scene, {
      entries = function()
        return model:get_entries()
      end,
    }, {
      row = 1,
      width = '25vw',
    }, {
      elements = {
        header = false,
        footer = false,
      },
    }),
  }
end

function ProjectDiffScreen:hunk_up()
  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
  self.diff_view:prev(hunk_alignment)
end

function ProjectDiffScreen:hunk_down()
  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
  self.diff_view:next(hunk_alignment)
end

function ProjectDiffScreen:move_to(query_fn)
  return self.status_list_view:move_to(query_fn)
end

function ProjectDiffScreen:stage_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' then return end

  loop.free_textlock()
  local hunk = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local _, err = self.model:stage_hunk(filename, hunk)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    local has_unstaged = false
    self.status_list_view:each_status(function(status, entry_type)
      if entry_type == 'unstaged' and status.filename == filename then
        has_unstaged = true
      end
    end)

    if has_unstaged then
      -- Stay on the unstaged entry for this file
      self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == 'unstaged'
      end)
    else
      -- File fully staged - jump to next unstaged file, else this file's staged
      local found = self:move_to(function(_, entry_type)
        return entry_type == 'unstaged'
      end)
      if not found then
        self:move_to(function(status)
          return status.filename == filename
        end)
      end
    end
  end)
end

function ProjectDiffScreen:unstage_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local hunk = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local _, err = self.model:unstage_hunk(filename, hunk)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    local has_staged = false
    self.status_list_view:each_status(function(status, entry_type)
      if entry_type == 'staged' and status.filename == filename then
        has_staged = true
      end
    end)

    if has_staged then
      -- Stay on the staged entry for this file
      self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == 'staged'
      end)
    else
      -- File fully unstaged - jump to next staged file, else this file's unstaged
      local found = self:move_to(function(_, entry_type)
        return entry_type == 'staged'
      end)
      if not found then
        self:move_to(function(status)
          return status.filename == filename
        end)
      end
    end
  end)
end

function ProjectDiffScreen:reset_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' then return end

  loop.free_textlock()
  local hunk = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard this hunk? (y/N) '):lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local _, err = self.model:reset_hunk(filename, hunk)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    -- Stay on this file if it still has unstaged hunks, else jump to next
    local has_unstaged = false
    self.status_list_view:each_status(function(status, entry_type)
      if entry_type == 'unstaged' and status.filename == filename then
        has_unstaged = true
      end
    end)

    if has_unstaged then
      self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == 'unstaged'
      end)
    else
      local found = self:move_to(function(_, entry_type)
        return entry_type == 'unstaged'
      end)
      if not found then
        self:move_to(function(status)
          return status.filename == filename
        end)
      end
    end
  end)
end

function ProjectDiffScreen:stage_file()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' and entry.type ~= 'unmerged' then return end

  loop.free_textlock()
  local filename = entry.status.filename
  local _, err = self.model:stage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    local has_unstaged = false
    self.status_list_view:each_status(function(status)
      if status:is_staged() then
        has_unstaged = true
      end
    end)

    self:move_to(function(status)
      if has_unstaged then return status:is_unstaged() == true end
      return status.filename == entry.status.filename
    end)
  end)
end

function ProjectDiffScreen:unstage_file()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local filename = entry.status.filename
  local _, err = self.model:unstage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    local has_staged = false
    self.status_list_view:each_status(function(status)
      if status:is_staged() then
        has_staged = true
      end
    end)

    self:move_to(function(status)
      if has_staged then return status:is_staged() == true end
      return status.filename == entry.status.filename
    end)
  end)
end

function ProjectDiffScreen:stage_all()
  local _, err = self.model:stage_all()
  if err then
    console.debug.error(err)
    return
  end

  local entry = self.model:get_entry()
  self:render(function()
    if not entry then return end
    self:move_to(function(status)
      return status.filename == entry.status.filename
    end)
  end)
end

function ProjectDiffScreen:unstage_all()
  local _, err = self.model:unstage_all()
  if err then
    console.debug.error(err)
    return
  end

  local entry = self.model:get_entry()
  self:render(function()
    if not entry then return end
    self:move_to(function(status)
      return status.filename == entry.status.filename
    end)
  end)
end

function ProjectDiffScreen:commit()
  self:destroy()
  vim.cmd('VGit project_commit_preview')
end

function ProjectDiffScreen:reset_file()
  local filename = self.model:get_filename()
  if not filename then return end

  loop.free_textlock()
  local decision =
      console.input(string.format('Are you sure you want to discard changes in %s? (y/N) ', filename)):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local _, err = self.model:reset_file(filename)
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return
  end

  self:render()
end

function ProjectDiffScreen:reset_all()
  loop.free_textlock()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  loop.free_textlock()
  local _, err = self.model:reset_all()
  loop.free_textlock()

  if err then
    console.debug.error(err)
    return
  end

  self:render()
end

function ProjectDiffScreen:enter_view()
  local mark = self.diff_view:get_current_mark_under_cursor()
  if not mark then return end

  local filepath = self.model:get_filepath()
  loop.free_textlock()
  if not filepath then return end

  self:destroy()

  fs.open(filepath)
  Window(0):set_lnum(mark.top_relative):position_cursor('center')
end

function ProjectDiffScreen:open_file()
  local filename = self.model:get_filepath()
  if not filename then return end

  local mark = self.diff_view:get_current_mark_under_cursor()

  loop.free_textlock()
  self:destroy()
  fs.open(filename)

  if not mark then
    local diff, diff_err = self.model:get_diff()
    if diff_err or not diff then return end
    mark = diff.marks[1]
    if not mark then return end
  end

  Window(0):set_lnum(mark.top_relative):position_cursor('center')
end

function ProjectDiffScreen:render(on_status_list_render)
  local entries = self.model:fetch()
  loop.free_textlock()

  if utils.object.is_empty(entries) then return self:destroy() end

  self.status_list_view:render()
  if on_status_list_render then on_status_list_render() end

  local list_item = self.status_list_view:get_current_list_item()
  self.model:set_entry_id(list_item.id)

  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
  self.diff_view:render()
  self.diff_view:move_to_hunk(nil, hunk_alignment)
end

function ProjectDiffScreen:handle_list_move()
  local list_item = self.status_list_view:move()
  if not list_item then return end

  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
  self.model:set_entry_id(list_item.id)
  self.diff_view:render()
  self.diff_view:move_to_hunk(nil, hunk_alignment)
end

function ProjectDiffScreen:focus_relative_buffer_entry(buffer)
  local filename = buffer:get_relative_name()

  -- Try to find current buffer's file, preferring unstaged
  if filename ~= '' then
    local list_item = self:move_to(function(status, entry_type)
      return status.filename == filename and entry_type == 'unstaged'
    end)
    if list_item then return end

    -- Fall back to staged entry for this file
    list_item = self:move_to(function(status)
      return status.filename == filename
    end)
    if list_item then return end
  end

  -- Fallback: prefer unstaged entries, then any entry
  local found = self:move_to(function(_, entry_type)
    return entry_type == 'unstaged'
  end)
  if not found then
    self:move_to(function()
      return true
    end)
  end
end

function ProjectDiffScreen:toggle_focus()
  local list_component = self.scene:get('list')
  local diff_component = self.scene:get('current')

  if list_component:is_focused() then
    local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
    diff_component:focus()
    self.diff_view:move_to_hunk(1, hunk_alignment)
  else
    list_component:focus()
  end
end

function ProjectDiffScreen:setup_list_keymaps()
  local keymaps = project_diff_preview_setting:get('keymaps')

  self.status_list_view:set_keymap({
    {
      mode = 'n',
      mapping = keymaps.commit,
      handler = loop.coroutine(function()
        self:commit()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_reset,
      handler = loop.coroutine(function()
        self:reset_file()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_stage,
      handler = loop.coroutine(function()
        self:stage_file()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_unstage,
      handler = loop.coroutine(function()
        self:unstage_file()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.stage_all,
      handler = loop.coroutine(function()
        self:stage_all()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.unstage_all,
      handler = loop.coroutine(function()
        self:unstage_all()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.reset_all,
      handler = loop.coroutine(function()
        self:reset_all()
      end),
    },
    {
      mode = 'n',
      mapping = keymaps.toggle_focus,
      handler = function()
        self:toggle_focus()
      end,
    },
  })
end

function ProjectDiffScreen:setup_diff_keymaps()
  local keymaps = project_diff_preview_setting:get('keymaps')

  -- Create debounced handlers and store them for cleanup
  local handlers = {
    hunk_stage = loop.debounce_coroutine(function()
      self:stage_hunk()
    end, 15),
    hunk_unstage = loop.debounce_coroutine(function()
      self:unstage_hunk()
    end, 15),
    hunk_reset = loop.debounce_coroutine(function()
      self:reset_hunk()
    end, 15),
    reset = loop.debounce_coroutine(function()
      self:reset_file()
    end, 15),
    stage = loop.debounce_coroutine(function()
      self:stage_file()
    end, 15),
    unstage = loop.debounce_coroutine(function()
      self:unstage_file()
    end, 15),
    stage_all = loop.debounce_coroutine(function()
      self:stage_all()
    end, 15),
    unstage_all = loop.debounce_coroutine(function()
      self:unstage_all()
    end, 15),
    reset_all = loop.debounce_coroutine(function()
      self:reset_all()
    end, 15),
    commit = loop.debounce_coroutine(function()
      self:commit()
    end, 15),
    enter = loop.coroutine(function()
      self:enter_view()
    end),
  }

  self.diff_keymaps = handlers

  self.diff_view:set_keymap({
    {
      mode = 'n',
      mapping = keymaps.buffer_hunk_stage,
      handler = handlers.hunk_stage,
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_hunk_unstage,
      handler = handlers.hunk_unstage,
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_hunk_reset,
      handler = handlers.hunk_reset,
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_reset,
      handler = handlers.reset,
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_stage,
      handler = handlers.stage,
    },
    {
      mode = 'n',
      mapping = keymaps.buffer_unstage,
      handler = handlers.unstage,
    },
    {
      mode = 'n',
      mapping = keymaps.stage_all,
      handler = handlers.stage_all,
    },
    {
      mode = 'n',
      mapping = keymaps.unstage_all,
      handler = handlers.unstage_all,
    },
    {
      mode = 'n',
      mapping = keymaps.reset_all,
      handler = handlers.reset_all,
    },
    {
      mode = 'n',
      mapping = keymaps.commit,
      handler = handlers.commit,
    },
    {
      mode = 'n',
      mapping = keymaps.toggle_focus,
      handler = function()
        self:toggle_focus()
      end,
    },
    {
      mode = 'n',
      mapping = {
        key = '<enter>',
        desc = 'Open buffer'
      },
      handler = handlers.enter,
    },
  })
end

function ProjectDiffScreen:setup_keymaps()
  self:setup_list_keymaps()
  self:setup_diff_keymaps()
end

function ProjectDiffScreen:create()
  local buffer = Buffer(0)

  local data, err = self.model:fetch()
  loop.free_textlock()

  if err then
    console.debug.error(err).error(err)
    return false
  end

  if utils.object.is_empty(data) then
    if self.model:conflict_status() then
      console.info('All conflicts fixed but you are still merging')
      return false
    end
    console.info('No changes found')
    return false
  end

  self.app_bar_view:define()
  self.diff_view:define()
  self.status_list_view:define()

  self.diff_view:mount()
  self.app_bar_view:mount()
  self.status_list_view:mount({
    event_handlers = {
      on_enter = function()
        self:open_file()
      end,
      on_move = function()
        self:handle_list_move()
      end,
    },
  })

  self.diff_view:render()
  self.app_bar_view:render()
  self.status_list_view:render()

  self:setup_keymaps()
  self:focus_relative_buffer_entry(buffer)
  self:handle_list_move()
  self:toggle_focus()

  return true
end

function ProjectDiffScreen:destroy()
  -- Clean up timer handles from debounced keymap handlers
  loop.close_debounced_handlers(self.diff_keymaps)
  self.diff_keymaps = {}

  self.scene:destroy()
end

return ProjectDiffScreen
