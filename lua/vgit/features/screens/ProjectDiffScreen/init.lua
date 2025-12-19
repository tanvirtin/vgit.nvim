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
          { 'Next',         keymaps['next'] },
          { 'Previous',     keymaps['previous'] },
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

function ProjectDiffScreen:move_to(query_fn)
  return self.status_list_view:move_to(query_fn)
end

-- Find the next file of given entry_type after current filename
function ProjectDiffScreen:find_next_file(filename, target_entry_type)
  local next_filename = nil
  local found_current = false
  self.status_list_view:each_status(function(status, entry_type)
    if entry_type == target_entry_type then
      if found_current and not next_filename then
        next_filename = status.filename
      end
      if status.filename == filename then
        found_current = true
      end
    end
  end)
  return next_filename
end

-- Restore cursor to same hunk index after staging/unstaging/resetting a hunk
function ProjectDiffScreen:restore_hunk_position(filename, entry_type, hunk_index)
  local new_entry = self.model:get_entry()
  if new_entry
      and new_entry.type == entry_type
      and new_entry.status.filename == filename then
    local diff = self.model:get_diff()
    if diff and diff.marks and #diff.marks > 0 then
      local target = math.min(hunk_index, #diff.marks)
      local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
      self.diff_view:move_to_hunk(target, hunk_alignment)
    end
  end
end

function ProjectDiffScreen:stage_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' then return end

  loop.free_textlock()
  local hunk, hunk_index = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

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
      self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == 'unstaged'
      end)
    elseif next_file then
      self:move_to(function(status, entry_type)
        return status.filename == next_file and entry_type == 'unstaged'
      end)
    else
      self:move_to(function(status)
        return status.filename == filename
      end)
    end
  end)

  self:restore_hunk_position(filename, 'unstaged', hunk_index)
end

function ProjectDiffScreen:unstage_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local hunk, hunk_index = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'staged')

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
      self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == 'staged'
      end)
    elseif next_file then
      self:move_to(function(status, entry_type)
        return status.filename == next_file and entry_type == 'staged'
      end)
    else
      self:move_to(function(status)
        return status.filename == filename
      end)
    end
  end)

  self:restore_hunk_position(filename, 'staged', hunk_index)
end

function ProjectDiffScreen:reset_hunk()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' then return end

  loop.free_textlock()
  local hunk, hunk_index = self.diff_view:get_hunk_under_cursor()
  if not hunk then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

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
    elseif next_file then
      self:move_to(function(status, entry_type)
        return status.filename == next_file and entry_type == 'unstaged'
      end)
    else
      self:move_to(function(status)
        return status.filename == filename
      end)
    end
  end)

  self:restore_hunk_position(filename, 'unstaged', hunk_index)
end

function ProjectDiffScreen:stage_file()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'unstaged' and entry.type ~= 'unmerged' then return end

  loop.free_textlock()
  local filename = entry.status.filename

  -- Find the next unstaged file after this one (before staging)
  local next_unstaged_filename = nil
  local found_current = false
  self.status_list_view:each_status(function(status, entry_type)
    if entry_type == 'unstaged' or entry_type == 'unmerged' then
      if found_current and not next_unstaged_filename then
        next_unstaged_filename = status.filename
      end
      if status.filename == filename then
        found_current = true
      end
    end
  end)

  local _, err = self.model:stage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    if next_unstaged_filename then
      -- Go to the next unstaged file
      self:move_to(function(status, entry_type)
        return status.filename == next_unstaged_filename
            and (entry_type == 'unstaged' or entry_type == 'unmerged')
      end)
    else
      -- No next unstaged file - try first unstaged, then staged version
      local found = self:move_to(function(_, entry_type)
        return entry_type == 'unstaged' or entry_type == 'unmerged'
      end)
      if not found then
        self:move_to(function(status)
          return status.filename == filename
        end)
      end
    end
  end)
end

function ProjectDiffScreen:unstage_file()
  local entry = self.model:get_entry()
  if not entry then return end
  if entry.type ~= 'staged' then return end

  loop.free_textlock()
  local filename = entry.status.filename

  -- Find the next staged file after this one (before unstaging)
  local next_staged_filename = nil
  local found_current = false
  self.status_list_view:each_status(function(status, entry_type)
    if entry_type == 'staged' then
      if found_current and not next_staged_filename then
        next_staged_filename = status.filename
      end
      if status.filename == filename then
        found_current = true
      end
    end
  end)

  local _, err = self.model:unstage_file(filename)
  if err then
    console.debug.error(err)
    return
  end

  self:render(function()
    if next_staged_filename then
      -- Go to the next staged file
      self:move_to(function(status, entry_type)
        return status.filename == next_staged_filename and entry_type == 'staged'
      end)
    else
      -- No next staged file - try first staged, then unstaged version
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

function ProjectDiffScreen:get_current_mark_index()
  loop.free_textlock()
  local diff = self.model:get_diff()
  if not diff or not diff.marks or #diff.marks == 0 then
    return nil, 0
  end

  local marks = diff.marks
  local lnum = self.diff_view.scene:get('current'):get_lnum()

  for i, mark in ipairs(marks) do
    if lnum >= mark.top and lnum <= mark.bot then
      return i, #marks
    elseif mark.top > lnum then
      return math.max(1, i - 1), #marks
    end
  end

  return #marks, #marks
end

function ProjectDiffScreen:move_to_next_file()
  loop.free_textlock()
  local component = self.status_list_view.scene:get('list')
  local current_lnum = component:get_lnum()
  local count = component:get_line_count()

  -- Find next file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum + offset
    if target_lnum > count then target_lnum = target_lnum - count end

    local item = self.status_list_view:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      component:unlock():set_lnum(target_lnum):lock()
      return item
    end
  end
  return nil
end

function ProjectDiffScreen:move_to_prev_file()
  loop.free_textlock()
  local component = self.status_list_view.scene:get('list')
  local current_lnum = component:get_lnum()
  local count = component:get_line_count()

  -- Find previous file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum - offset
    if target_lnum < 1 then target_lnum = target_lnum + count end

    local item = self.status_list_view:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      component:unlock():set_lnum(target_lnum):lock()
      return item
    end
  end
  return nil
end

function ProjectDiffScreen:next_hunk()
  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')

  if not current_index or total_hunks == 0 or current_index >= total_hunks then
    -- At last hunk or no hunks - move to next file
    local list_item = self:move_to_next_file()
    if not list_item then return end
    self.model:set_entry_id(list_item.id)
    self.diff_view:render()
    self.diff_view:move_to_hunk(1, hunk_alignment)
  else
    self.diff_view:next(hunk_alignment)
  end
end

function ProjectDiffScreen:prev_hunk()
  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')

  if not current_index or total_hunks == 0 or current_index <= 1 then
    -- At first hunk or no hunks - move to previous file's last hunk
    local list_item = self:move_to_prev_file()
    if not list_item then return end
    self.model:set_entry_id(list_item.id)
    self.diff_view:render()
    -- Pass 0 to go to last hunk (move_to_hunk clamps <1 to #marks)
    self.diff_view:move_to_hunk(0, hunk_alignment)
  else
    self.diff_view:prev(hunk_alignment)
  end
end

function ProjectDiffScreen:focus_relative_buffer_entry(buffer)
  local filename = buffer:get_relative_name()
  local last_entry_type = vim.b[buffer.bufnr].vgit_last_entry_type

  -- Try to find current buffer's file
  if filename ~= '' then
    -- If we have a hint from last quit, prefer that entry type
    if last_entry_type then
      local list_item = self:move_to(function(status, entry_type)
        return status.filename == filename and entry_type == last_entry_type
      end)
      if list_item then return end
    end

    -- Otherwise prefer unstaged
    local list_item = self:move_to(function(status, entry_type)
      return status.filename == filename and entry_type == 'unstaged'
    end)
    if list_item then return end

    -- Fall back to any entry for this file
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
    {
      mode = 'n',
      mapping = keymaps.next,
      handler = loop.debounce_coroutine(function()
        local list_item = self:move_to_next_file()
        if not list_item then return end
        self.model:set_entry_id(list_item.id)
        local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
        self.diff_view:render()
        self.diff_view:move_to_hunk(1, hunk_alignment)
      end, 15),
    },
    {
      mode = 'n',
      mapping = keymaps.previous,
      handler = loop.debounce_coroutine(function()
        local list_item = self:move_to_prev_file()
        if not list_item then return end
        self.model:set_entry_id(list_item.id)
        local hunk_alignment = project_diff_preview_setting:get('hunk_alignment')
        self.diff_view:render()
        self.diff_view:move_to_hunk(0, hunk_alignment)
      end, 15),
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
    next_hunk = loop.debounce_coroutine(function()
      self:next_hunk()
    end, 15),
    prev_hunk = loop.debounce_coroutine(function()
      self:prev_hunk()
    end, 15),
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
      mapping = keymaps.next,
      handler = handlers.next_hunk,
    },
    {
      mode = 'n',
      mapping = keymaps.previous,
      handler = handlers.prev_hunk,
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

-- Called when quit key is pressed. Returns true if quit was handled.
function ProjectDiffScreen:on_quit()
  local diff_component = self.scene:get('current')
  if not diff_component:is_focused() then
    return false
  end

  local filepath = self.model:get_filepath()
  if not filepath then
    return false
  end

  local entry = self.model:get_entry()
  local file_lnum = self.diff_view:get_file_lnum()
  loop.free_textlock()

  self:destroy()
  fs.open(filepath)

  -- Store entry type so re-opening returns to same entry
  if entry then
    vim.b.vgit_last_entry_type = entry.type
  end

  if file_lnum then
    Window(0):set_lnum(file_lnum):position_cursor('center')
  end

  return true
end

function ProjectDiffScreen:destroy()
  -- Clean up timer handles from debounced keymap handlers
  loop.close_debounced_handlers(self.diff_keymaps)
  self.diff_keymaps = {}

  self.scene:destroy()
end

return ProjectDiffScreen
