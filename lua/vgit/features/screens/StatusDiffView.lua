local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Layout = require('vgit.ui.Layout')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local view_utils = require('vgit.features.screens.view_utils')
local hunks_setting = require('vgit.settings.hunks')
local status_diff_view_setting = require('vgit.settings.status_diff_view')
local ComponentManager = require('vgit.ui.ComponentManager')
local TreeComponent = require('vgit.ui.components.TreeComponent')
local DiffComponent = require('vgit.ui.components.DiffComponent')
local LayoutComponent = require('vgit.ui.components.LayoutComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

local StatusDiffView = Object:extend()

StatusDiffView.DEBOUNCE_MS = 100
StatusDiffView.TREE_WIDTH = 50
StatusDiffView.LAYOUT_SPLIT = 'split'
StatusDiffView.LAYOUT_UNIFIED = 'unified'

function StatusDiffView:constructor()
  return {
    opts = {
      layout_type = self.LAYOUT_UNIFIED,
    },
    data = nil,
    repo = nil,
    current_entry = nil,
    diff_component = nil,
    tree_component = nil,
    component_manager = nil,
    debounce_cleanups = {},
  }
end

function StatusDiffView:_is_valid_entry(entry)
  if not entry then return false end
  if not entry.status then return false end
  if not entry.status.filename or type(entry.status.filename) ~= 'string' then return false end
  return true
end

function StatusDiffView:_set_current_entry(entry)
  if self:_is_valid_entry(entry) then
    self.current_entry = entry
    return true
  end
  return false
end

function StatusDiffView:get_current_mark_index()
  local marks = self.diff_component:get_marks()
  if not marks or #marks == 0 then return nil, 0 end

  local lnum = self.diff_component:get_lnum()

  for i, mark in ipairs(marks) do
    if lnum >= mark.top and lnum <= mark.bot then
      return i, #marks
    elseif mark.top > lnum then
      return math.max(1, i - 1), #marks
    end
  end

  return #marks, #marks
end

function StatusDiffView:get_hunk_alignment()
  return view_utils.get_hunk_alignment()
end

function StatusDiffView:hunk_down()
  if not self.diff_component or not self.diff_component:is_valid() then return end

  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = self:get_hunk_alignment()

  if not current_index or total_hunks == 0 or current_index >= total_hunks then
    -- At last hunk or no hunks - move to next file
    local item = self:move_to_next_file()
    if not item then return end
    event.await()
    self:_update_diff_component()
    event.await()
    if self.diff_component and self.diff_component:is_valid() then
      self.diff_component:move_to_hunk(1, hunk_alignment)
    end
  else
    self.diff_component:hunk_down(hunk_alignment)
  end
end

function StatusDiffView:hunk_up()
  if not self.diff_component or not self.diff_component:is_valid() then return end

  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = self:get_hunk_alignment()

  if not current_index or total_hunks == 0 or current_index <= 1 then
    -- At first hunk or no hunks - move to previous file's last hunk
    local item = self:move_to_prev_file()
    if not item then return end
    event.await()
    self:_update_diff_component()
    event.await()
    -- Pass 0 to go to last hunk
    if self.diff_component and self.diff_component:is_valid() then
      self.diff_component:move_to_hunk(0, hunk_alignment)
    end
  else
    self.diff_component:hunk_up(hunk_alignment)
  end
end

function StatusDiffView:reset_hunk()
  event.await()

  if not self:_is_valid_entry(self.current_entry) then return end
  if self.current_entry.type ~= 'unstaged' then return end

  local hunk, hunk_index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  -- Confirmation prompt
  event.await()
  local decision = console.input('Are you sure you want to discard this hunk? (y/N) '):lower()
  if decision ~= 'y' and decision ~= 'yes' then return end

  local filename = self.current_entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then return end

  local _, reset_err = repo:reset_hunk(filename, hunk)
  if reset_err then
    console.debug.error(string.format('[StatusDiffView] reset_hunk failed: %s', reset_err))
    return
  end

  self:refresh_after_hunk_operation(filename, hunk_index, 'unstaged', next_file)
end

function StatusDiffView:find_next_file(filename, target_type)
  local next_filename = nil
  local found_current = false

  self.tree_component:each_entry(function(status, entry_type)
    if entry_type == target_type then
      if found_current and not next_filename then next_filename = status.filename end
      if status.filename == filename then found_current = true end
    end
  end)

  return next_filename
end

function StatusDiffView:move_to_entry(filename, entry_type)
  self.tree_component:move_to(function(status, et)
    return status.filename == filename and et == entry_type
  end)
end

function StatusDiffView:restore_hunk_position(hunk_index)
  event.await()

  local marks = self.diff_component.state and self.diff_component.state.marks
  if marks and #marks > 0 then
    local target = math.min(hunk_index, #marks)
    self.diff_component:move_to_hunk(target, self:get_hunk_alignment())
  end
end

function StatusDiffView:refresh_after_hunk_operation(filename, hunk_index, entry_type, next_file)
  self:refresh_data()
  event.await()

  local still_has_entries = false
  self.tree_component:each_entry(function(status, et)
    if et == entry_type and status.filename == filename then still_has_entries = true end
  end)

  if still_has_entries then
    self:move_to_entry(filename, entry_type)
    event.await()
    self:_update_diff_component()
    self:restore_hunk_position(hunk_index)
  elseif next_file then
    self:move_to_entry(next_file, entry_type)
  else
    self.tree_component:move_to(function(status)
      return status ~= nil
    end)
  end
end

function StatusDiffView:move_to_next_file()
  if not self.tree_component or not self.tree_component:is_valid() then return nil end

  local current_lnum = self.tree_component._element:get_lnum()
  local count = self.tree_component._element:get_line_count()

  -- Find next file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum + offset
    if target_lnum > count then target_lnum = target_lnum - count end

    local item = self.tree_component:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      self.tree_component._element:set_lnum(target_lnum)
      self:_set_current_entry(item.entry)
      return item
    end
  end

  return nil
end

function StatusDiffView:move_to_prev_file()
  if not self.tree_component or not self.tree_component:is_valid() then return nil end

  local current_lnum = self.tree_component._element:get_lnum()
  local count = self.tree_component._element:get_line_count()

  -- Find previous file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum - offset
    if target_lnum < 1 then target_lnum = target_lnum + count end

    local item = self.tree_component:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      self.tree_component._element:set_lnum(target_lnum)
      self:_set_current_entry(item.entry)
      return item
    end
  end

  return nil
end

function StatusDiffView:navigate_down()
  self:hunk_down()
end

function StatusDiffView:navigate_up()
  self:hunk_up()
end

function StatusDiffView:_handle_git_error(err, operation_name)
  return view_utils.handle_git_error(err, operation_name, 'StatusDiffView')
end

function StatusDiffView:_build_entry_diff(entry, repo)
  if not self:_is_valid_entry(entry) then return nil, { 'entry is invalid' } end

  local entry_type = entry.type
  local status = entry.status
  local filename = status.filename

  local diff_spec
  if entry_type == 'staged' then
    diff_spec = {
      type = 'range',
      filename = filename,
      from = 'HEAD',
      to = 'index',
    }
  elseif entry_type == 'unmerged' then
    diff_spec = {
      type = 'conflict',
      filename = filename,
    }
  else
    diff_spec = {
      type = 'range',
      filename = filename,
      from = 'index',
      to = 'disk',
    }
  end

  local opts = {}
  if self.opts.layout_type then opts.layout_type = self.opts.layout_type end

  event.await()
  return repo:diff(diff_spec, opts)
end

function StatusDiffView:create(data)
  if not data then
    event.await()
    console.error('[StatusDiffView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    event.await()
    console.error('[StatusDiffView] Expected table, got ' .. type(data))
    return false
  end

  if not data.entries then
    event.await()
    console.error('[StatusDiffView] Invalid data: missing entries')
    return false
  end
  if type(data.entries) ~= 'table' then
    event.await()
    console.error('[StatusDiffView] Invalid data: entries must be a table')
    return false
  end
  if utils.object.is_empty(data.entries) then
    event.await()
    console.error('[StatusDiffView] Invalid data: entries list is empty')
    return false
  end

  return self:_process_entries_data(data)
end

function StatusDiffView:_process_entries_data(data)
  self.opts = utils.object.defaults({
    layout_type = data.layout_type,
  }, self.opts)

  self.data = data

  local entries_data = {
    entries = data.entries,
    layout_type = self.opts.layout_type,
  }

  return self:_create_entries_view(entries_data)
end

function StatusDiffView:move_to(query_fn)
  return self.tree_component:move_to(query_fn)
end

function StatusDiffView:create_diff_component(opts)
  opts = opts or {}
  local layout_type = self.opts.layout_type or self.LAYOUT_UNIFIED

  local props = {
    diff = opts.diff,
    filename = opts.filename,
    filetype = opts.filetype or 'text',
  }

  if layout_type == self.LAYOUT_SPLIT then return SplitDiffComponent(props) end
  return DiffComponent(props)
end

function StatusDiffView:_update_diff_component(hunk_index)
  event.await()
  if not self:_is_valid_entry(self.current_entry) then return false end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return false end

  event.await()
  local diff_data, err = self:_build_entry_diff(self.current_entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return false end

  event.await()
  self.diff_component:set_props({
    diff = diff_data,
    filename = self.current_entry.status.filename,
    filetype = self.current_entry.status.filetype,
  })

  if hunk_index then
    event.await()
    self.diff_component:move_to_hunk(hunk_index, self:get_hunk_alignment())
  end

  return true
end

function StatusDiffView:stage_hunk()
  event.await()

  if not self:_is_valid_entry(self.current_entry) then return end
  if self.current_entry.type ~= 'unstaged' then return end

  local filename = self.current_entry.status.filename

  local hunk, hunk_index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  -- Find next unstaged file before staging
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then return end

  local _, stage_err = repo:stage_hunk(filename, hunk)
  if stage_err then
    console.debug.error(string.format('[StatusDiffView] stage_hunk failed: %s', stage_err))
    return
  end

  self:refresh_after_hunk_operation(filename, hunk_index, 'unstaged', next_file)
end

function StatusDiffView:unstage_hunk()
  event.await()

  if not self:_is_valid_entry(self.current_entry) then return end
  if self.current_entry.type ~= 'staged' then return end

  local filename = self.current_entry.status.filename

  local hunk, hunk_index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local next_file = self:find_next_file(filename, 'staged')

  local repo, err = repository.current()
  if err then return end

  local _, unstage_err = repo:unstage_hunk(filename, hunk)
  if unstage_err then
    console.debug.error(string.format('[StatusDiffView] unstage_hunk failed: %s', unstage_err))
    return
  end

  self:refresh_after_hunk_operation(filename, hunk_index, 'staged', next_file)
end

function StatusDiffView:stage_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:stage_file(filename)
end

function StatusDiffView:unstage_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:unstage_file(filename)
end

function StatusDiffView:reset_entry()
  if not self:_is_valid_entry(self.current_entry) then return end

  event.await()
  local decision = console.input('Are you sure you want to discard changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  local filename = self.current_entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:reset(filename)
end

function StatusDiffView:commit()
  event.await()
  local message = console.input('Commit message: ')

  if not message or message:match('^%s*$') then
    console.info('Commit cancelled: empty message')
    return
  end

  event.await()
  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local _, err = repo:commit(message)
  if not self:_handle_git_error(err, 'commit') then return end

  console.info('Changes committed successfully')
end

function StatusDiffView:open_file()
  if not self:_is_valid_entry(self.current_entry) then return end

  local filename = self.current_entry.status.filename

  self:destroy()
  event.await()
  fs.open(filename)
end

function StatusDiffView:_handle_file_selection_change(item)
  if not self.component_manager then return end

  if not item then
    console.warn('[StatusDiffView] file selection changed called with nil item')
    return
  end

  self.diff_component:clear_extmarks()
  self.diff_component:clear_lines()
  self.diff_component:clear_folds()
  self.diff_component:reset_cursor()

  local entry = item.entry or item
  if not self:_set_current_entry(entry) then return end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return end

  if self.diff_component then
    local has_content = diff_data and diff_data.marks and #diff_data.marks > 0

    if has_content then
      event.await()
      self.diff_component:set_props({
        diff = diff_data,
        filename = entry.status.filename,
        filetype = entry.status.filetype or 'text',
      })

      if self.diff_component.call then
        event.await()
        self.diff_component:call(function()
          self.diff_component:move_to_hunk(1, self:get_hunk_alignment())
        end)
      end
    else
      event.await()
      self.diff_component:set_props({
        diff = nil,
        filename = nil,
        filetype = nil,
      })
    end
  end
end

function StatusDiffView:stage_all()
  local repo, err = repository.current()
  if err then return end
  repo:stage_all()
end

function StatusDiffView:unstage_all()
  local repo, err = repository.current()
  if err then return end
  repo:unstage_all()
end

function StatusDiffView:reset_all()
  event.await()
  local decision = console.input('Are you sure you want to discard all changes? (y/N) '):lower()

  if decision ~= 'yes' and decision ~= 'y' then return end

  local repo, err = repository.current()
  if err then return end
  repo:reset()
end

function StatusDiffView:refresh_data()
  event.await()

  local repo, err = repository.current()
  if err then return end

  event.await()

  local data, status_err = repo:status(self.opts)
  if not self:_handle_git_error(status_err, 'status') then return end

  if not data or utils.object.is_empty(data.entries) then
    console.warn('[StatusDiffView] No data returned from refresh_data()')
    return
  end

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
  end

  self.tree_component:set_list(file_groups)
end

function StatusDiffView:get_key(keymap)
  return view_utils.get_key(keymap)
end

function StatusDiffView:setup_keymaps()
  local scene_setting = require('vgit.settings.scene')
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = status_diff_view_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      event.await()
      if self.tree_component:is_valid() then
        self.tree_component:set_keymap('n', quit_key, function()
          self.component_manager:destroy()
        end, 'Quit')
      end

      self.diff_component:set_keymap({
        mode = 'n',
        key = quit_key,
      }, function()
        self.component_manager:destroy()
      end)
    end
  end

  local stage_hunk_key = self:get_key(diff_keymaps.stage_hunk)
  if stage_hunk_key then
    local stage_hunk_fn, stage_hunk_cleanup = event.debounce_async(function()
      self:stage_hunk()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, stage_hunk_cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = stage_hunk_key,
    }, stage_hunk_fn)
  end

  local unstage_hunk_key = self:get_key(diff_keymaps.unstage_hunk)
  if unstage_hunk_key then
    local unstage_hunk_fn, unstage_hunk_cleanup = event.debounce_async(function()
      self:unstage_hunk()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, unstage_hunk_cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = unstage_hunk_key,
    }, unstage_hunk_fn)
  end

  -- Reset hunk keymap
  local reset_hunk_key = self:get_key(diff_keymaps.reset_hunk)
  if reset_hunk_key then
    local reset_hunk_fn, reset_hunk_cleanup = event.debounce_async(function()
      self:reset_hunk()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, reset_hunk_cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = reset_hunk_key,
    }, reset_hunk_fn)
  end

  local down_key = self:get_key(hunks_keymaps.down)
  if down_key then
    local down_fn = event.async(function()
      self:navigate_down()
    end)

    self.diff_component:set_keymap({
      mode = 'n',
      key = down_key,
    }, down_fn)

    if self.tree_component:is_valid() then self.tree_component:set_keymap('n', down_key, down_fn, 'Next') end
  end

  local up_key = self:get_key(hunks_keymaps.up)
  if up_key then
    local up_fn = event.async(function()
      self:navigate_up()
    end)

    self.diff_component:set_keymap({
      mode = 'n',
      key = up_key,
    }, up_fn)

    if self.tree_component:is_valid() then self.tree_component:set_keymap('n', up_key, up_fn, 'Previous') end
  end

  local open_file_fn, open_file_cleanup = event.debounce_async(function()
    self:open_file()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, open_file_cleanup)
  self.diff_component:set_keymap({
    mode = 'n',
    key = '<enter>',
  }, open_file_fn)
end

function StatusDiffView:_create_entries_view(data)
  local repo, err = repository.current()
  if err then return false end

  self.repo = repo

  if repo:conflict_status() then
    event.await()
    console.info('All conflicts fixed but you are still merging')
    return false
  end

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
  end

  local initial_entry = nil
  for _, group in ipairs(file_groups) do
    if group.items and #group.items > 0 then
      initial_entry = group.items[1]
      break
    end
  end

  if initial_entry then
    if not self:_set_current_entry(initial_entry) then
      console.warn('[StatusDiffView] Initial entry failed validation')
    end
  end

  local diff_keymaps = status_diff_view_setting:get('keymaps')
  local tree_keymaps = {
    buffer_stage = diff_keymaps.stage,
    buffer_unstage = diff_keymaps.unstage,
    buffer_reset = diff_keymaps.reset,
    stage_all = diff_keymaps.stage_all,
    unstage_all = diff_keymaps.unstage_all,
    reset_all = diff_keymaps.reset_all,
    commit = diff_keymaps.commit,
  }

  self.tree_component = TreeComponent({
    list = file_groups,
    title = '',
    width = 50,
    focus = true,
    keymaps = tree_keymaps,
    keymap_handlers = {
      commit = function()
        self:commit()
      end,
      reset_file = function()
        self:reset_entry()
      end,
      stage_file = function()
        self:stage_entry()
      end,
      unstage_file = function()
        self:unstage_entry()
      end,
      stage_all = function()
        self:stage_all()
      end,
      unstage_all = function()
        self:unstage_all()
      end,
      reset_all = function()
        self:reset_all()
      end,
    },
  })

  self.tree_component:set_on_enter(function(item)
    if item and item.entry and item.entry.status then self:open_file() end
  end)

  local on_move_fn, on_move_cleanup = event.debounce_async(function(item)
    self:_handle_file_selection_change(item)
  end, self.DEBOUNCE_MS)

  table.insert(self.debounce_cleanups, on_move_cleanup)
  self.tree_component:set_on_move(on_move_fn)

  self.diff_component = self:create_diff_component({
    diff = nil,
    filename = nil,
    filetype = nil,
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.horizontal({
      LayoutSpec.view(self.tree_component, { width = '30%' }),
      LayoutSpec.view(self.diff_component, { expand = true }),
    }),
  })

  self.component_manager = ComponentManager()
  event.await()
  self.component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self.tree_component:component_did_mount()

  self:setup_keymaps()

  if self.tree_component and self.tree_component:is_valid() then self.tree_component:focus() end

  return true
end

function StatusDiffView:emit_cleanup_events()
  self.diff_component:component_will_unmount()
  self.tree_component:component_will_unmount()
end

function StatusDiffView:on_git_change()
  event.await()

  local filename = self.current_entry and self.current_entry.status and self.current_entry.status.filename
  local entry_type = self.current_entry and self.current_entry.type

  event.await()
  self:refresh_data()

  if filename then
    local found = false
    self.tree_component:each_entry(function(status, et)
      if not found and status.filename == filename and et == entry_type then found = true end
    end)

    if found then
      self:move_to_entry(filename, entry_type)
      event.await()
      self:_update_diff_component()
    else
      self.tree_component:move_to(function(status)
        return status ~= nil
      end)
    end
  end
end

function StatusDiffView:destroy()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
  self:emit_cleanup_events()
  self.component_manager:destroy()
end

return StatusDiffView
