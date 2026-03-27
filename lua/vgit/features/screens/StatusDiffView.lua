local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local navigation = lazy('vgit.core.navigation')
local repository = lazy('vgit.git.repository')
local hunks_setting = lazy('vgit.settings.hunks')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local TreeComponent = lazy('vgit.ui.components.TreeComponent')
local CommitView = lazy('vgit.features.screens.CommitView')
local status_diff_view_setting = lazy('vgit.settings.status_diff_view')

local StatusDiffView = View:extend()

StatusDiffView.DEBOUNCE_MS = 100
StatusDiffView.TREE_WIDTH = 50
StatusDiffView.LAYOUT_SPLIT = 'split'
StatusDiffView.LAYOUT_UNIFIED = 'unified'

function StatusDiffView:constructor()
  local instance = View.constructor(self)
  instance._opts = {
    layout_type = self.LAYOUT_UNIFIED,
  }
  instance._data = nil
  instance._repo = nil
  instance._diff_component = nil
  instance._tree_component = nil
  instance._commit_view = nil
  instance._refreshing = false
  instance._skip_on_move = false
  instance._diff_gen = 0
  return instance
end

function StatusDiffView:_is_valid_entry(entry)
  if not entry then return false end
  if not entry.status then return false end
  if not entry.status.filename or type(entry.status.filename) ~= 'string' then return false end
  return true
end

function StatusDiffView:get_current_entry()
  if not self._tree_component then return nil end
  return self._tree_component:get_selected_entry()
end

function StatusDiffView:get_navigatable_component()
  return self._diff_component
end

function StatusDiffView:get_hunk_alignment()
  return status_diff_view_setting:get('hunk_alignment')
end

function StatusDiffView:get_hunk_alignment_offset()
  return status_diff_view_setting:get('hunk_alignment_offset') or 0
end

function StatusDiffView:_after_hunk_operation(entry_type, filename, hunk_index, fallback_fn)
  self._refreshing = true
  local has_data = self:refresh_data()
  if has_data == false then
    self._refreshing = false
    self:destroy()
    return
  end

  local still_has_entries = false
  self._tree_component:each_entry(function(status, et)
    if et == entry_type and status.filename == filename then still_has_entries = true end
  end)

  if still_has_entries then
    self:move_to_entry(filename, entry_type)
    self._refreshing = false
    self:_refresh_diff()
    self:restore_hunk_position(hunk_index)
  else
    fallback_fn()
    self._refreshing = false
    self:_refresh_diff(1)
  end

  self._skip_on_move = true
  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk({ index = idx, count = count }) end
end

function StatusDiffView:reset_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local hunk, hunk_index = self._diff_component:get_hunk_under_cursor()
  if not hunk then return end

  if not self:_confirm('Are you sure you want to discard this hunk? (y/N) ') then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, reset_err = repo:reset_hunk(filename, hunk)
  if reset_err then
    console.debug.error(string.format('[StatusDiffView] reset_hunk failed: %s', reset_err))
    return
  end

  self:_after_hunk_operation('unstaged', filename, hunk_index, function()
    if next_file then
      self:move_to_entry(next_file, 'unstaged')
    else
      self:_navigate_to_preferred_entry('unstaged', 'staged')
    end
  end)
end

function StatusDiffView:find_next_file(filename, target_type)
  local next_filename = nil
  local found_current = false

  self._tree_component:each_entry(function(status, entry_type)
    if entry_type == target_type then
      if found_current and not next_filename then next_filename = status.filename end
      if status.filename == filename then found_current = true end
    end
  end)

  return next_filename
end

function StatusDiffView:move_to_entry(filename, entry_type)
  return self._tree_component:move_to(function(status, et)
    return status.filename == filename and et == entry_type
  end)
end

function StatusDiffView:restore_hunk_position(hunk_index)
  local marks = self._diff_component:get_marks()
  if #marks > 0 then
    local target = math.min(hunk_index, #marks)
    self._diff_component:move_to_hunk(target, self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  end
end

function StatusDiffView:_move_to_first_entry()
  self._tree_component:move_to(function(status)
    return status ~= nil
  end)
end

function StatusDiffView:_move_to_first_entry_of_type(target_type)
  return self._tree_component:move_to(function(status, entry_type)
    return status ~= nil and entry_type == target_type
  end) ~= nil
end

function StatusDiffView:_navigate_to_preferred_entry(preferred_type, fallback_type)
  if not self:_move_to_first_entry_of_type(preferred_type) then
    if not self:_move_to_first_entry_of_type(fallback_type) then self:_move_to_first_entry() end
  end
end

function StatusDiffView:refresh_and_navigate(navigate_fn)
  self._refreshing = true
  local has_data = self:refresh_data()
  if has_data == false then
    self._refreshing = false
    self:destroy()
    return
  end
  navigate_fn()
  self._refreshing = false
  self:_refresh_diff()
end

function StatusDiffView:_build_entry_diff(entry, repo)
  if not self:_is_valid_entry(entry) then return nil, { 'entry is invalid' } end

  local entry_type = entry.type
  local status = entry.status
  local filename = status.filename

  local old_filename = status.old_filename

  local diff_spec
  local index = repo:index()

  if entry_type == 'staged' then
    diff_spec = {
      type = 'range',
      filename = filename,
      old_filename = old_filename,
      from = 'HEAD',
      to = 'index',
      hunks = index:staged_hunks(filename),
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
      hunks = index:unstaged_hunks(filename),
    }
  end

  local opts = {}
  if self._opts.layout_type then opts.layout_type = self._opts.layout_type end

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
  self._opts = utils.object.defaults({
    layout_type = data.layout_type,
  }, self._opts)

  self._data = data

  local entries_data = {
    entries = data.entries,
    layout_type = self._opts.layout_type,
    current_filename = data.current_filename,
    cursor_lnum = data.cursor_lnum,
  }

  return self:_create_view(entries_data)
end

function StatusDiffView:move_to(query_fn)
  return self._tree_component:move_to(query_fn)
end

function StatusDiffView:_refresh_diff(hunk_index)
  self._diff_gen = self._diff_gen + 1
  local gen = self._diff_gen

  event.await()
  if self._diff_gen ~= gen then return false end

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return false end

  local repo, repo_err = repository.current()
  if repo_err then
    console.debug.error(repo_err)
    return false
  end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if err then
    console.debug.error(err)
    return false
  end
  if not diff_data then return false end

  if self._diff_gen ~= gen then return false end

  self._diff_component:set_props({
    diff = diff_data,
    filename = entry.status.filename,
    filetype = entry.status.filetype,
  })

  if hunk_index then
    self._diff_component:move_to_hunk(hunk_index, self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  end

  return true
end

function StatusDiffView:stage_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local filename = entry.status.filename

  local hunk, hunk_index = self._diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, stage_err = repo:stage_hunk(filename, hunk)
  if stage_err then
    console.debug.error(string.format('[StatusDiffView] stage_hunk failed: %s', stage_err))
    return
  end

  self:_after_hunk_operation('unstaged', filename, hunk_index, function()
    if not self:_move_to_first_entry_of_type('unstaged') then
      if not self:move_to_entry(filename, 'staged') then self:_navigate_to_preferred_entry('staged', 'unstaged') end
    end
  end)
end

function StatusDiffView:unstage_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'staged' then return end

  local filename = entry.status.filename

  local hunk, hunk_index = self._diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, unstage_err = repo:unstage_hunk(filename, hunk)
  if unstage_err then
    console.debug.error(string.format('[StatusDiffView] unstage_hunk failed: %s', unstage_err))
    return
  end

  self:_after_hunk_operation('staged', filename, hunk_index, function()
    if not self:_move_to_first_entry_of_type('staged') then
      if not self:move_to_entry(filename, 'unstaged') then self:_navigate_to_preferred_entry('unstaged', 'staged') end
    end
  end)
end

function StatusDiffView:stage_entry(opts)
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, stage_err = repo:stage_file(filename)
  if stage_err then
    console.debug.error(stage_err)
    return
  end

  local follow_same_file = opts and opts.follow_same_file

  self:refresh_and_navigate(function()
    if follow_same_file then
      if not self:move_to_entry(filename, 'staged') then self:_navigate_to_preferred_entry('staged', 'unstaged') end
    else
      if next_file then
        self:move_to_entry(next_file, 'unstaged')
      else
        self:_navigate_to_preferred_entry('unstaged', 'staged')
      end
    end
  end)
end

function StatusDiffView:unstage_entry(opts)
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'staged' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'staged')

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, unstage_err = repo:unstage_file(filename)
  if unstage_err then
    console.debug.error(unstage_err)
    return
  end

  local follow_same_file = opts and opts.follow_same_file

  self:refresh_and_navigate(function()
    if follow_same_file then
      if not self:move_to_entry(filename, 'unstaged') then self:_navigate_to_preferred_entry('unstaged', 'staged') end
    else
      if next_file then
        self:move_to_entry(next_file, 'staged')
      else
        self:_navigate_to_preferred_entry('staged', 'unstaged')
      end
    end
  end)
end

function StatusDiffView:reset_entry()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' and entry.type ~= 'staged' then return end

  event.await()
  if not self:_confirm('Are you sure you want to discard changes? (y/N) ') then return end

  local filename = entry.status.filename
  local entry_type = entry.type
  local next_file = self:find_next_file(filename, entry_type)

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  if entry_type == 'staged' then
    local _, unstage_err = repo:unstage_file(filename)
    if unstage_err then
      console.debug.error(unstage_err)
      return
    end
  end

  local _, reset_err = repo:reset(filename)
  if reset_err then
    console.debug.error(reset_err)
    return
  end

  self:refresh_and_navigate(function()
    if next_file then
      self:move_to_entry(next_file, entry_type)
    else
      self:_navigate_to_preferred_entry('unstaged', 'staged')
    end
  end)
end

function StatusDiffView:_is_commit_split_open()
  return self._commit_view and self._commit_view:is_valid() or false
end

function StatusDiffView:_close_commit_split()
  if self._commit_view then
    self._commit_view:destroy()
    self._commit_view = nil
  end
end

function StatusDiffView:_confirm_commit()
  if not self._commit_view or not self._commit_view:is_valid() then return end
  local lines = self._commit_view:get_lines()

  local message_lines = {}
  for _, line in ipairs(lines) do
    if not vim.startswith(line, '#') then message_lines[#message_lines + 1] = line end
  end

  self:_close_commit_split()

  local message = table.concat(message_lines, '\n')
  message = message:match('^%s*(.-)%s*$') or ''

  if message == '' then
    console.info('Commit cancelled: empty message')
    return
  end

  local repo, repo_err = repository.current()
  if repo_err then
    console.debug.error(repo_err)
    return
  end

  local _, err = repo:commit(message)
  if err then
    console.debug.error(err)
    return
  end

  console.info('Changes committed successfully')
end

function StatusDiffView:commit()
  event.await()

  if self:_is_commit_split_open() then
    self._commit_view:focus()
    return
  end

  local diff_keymaps = status_diff_view_setting:get('keymaps')
  local confirm_key = keymap.get_key(diff_keymaps.commit_confirm) or '<C-s>'
  local cancel_key = keymap.get_key(diff_keymaps.commit_cancel) or 'q'

  local lines = { '' }
  lines[#lines + 1] = '# Press ' .. confirm_key .. ' to confirm, ' .. cancel_key .. ' to cancel.'
  lines[#lines + 1] = '# Lines starting with # will be ignored.'

  local refs = self._repo:refs()
  if refs then
    local branch = refs:current_branch()
    if branch then
      lines[#lines + 1] = '#'
      lines[#lines + 1] = '# On branch ' .. branch
    end
  end

  if self._data and self._data.entries then
    for _, group in ipairs(self._data.entries) do
      if group.entries and #group.entries > 0 then
        lines[#lines + 1] = '#'
        lines[#lines + 1] = '# ' .. group.title .. ':'
        for _, entry in ipairs(group.entries) do
          if entry.status then lines[#lines + 1] = '#   ' .. entry.status.value .. ' ' .. entry.status.filename end
        end
      end
    end
  end

  self._commit_view = CommitView()
  self._commit_view:create({
    filetype = 'gitcommit',
    confirm_key = confirm_key,
    cancel_key = cancel_key,
    on_confirm = function()
      self:_confirm_commit()
    end,
    on_cancel = function()
      self:_close_commit_split()
      console.info('Commit cancelled')
    end,
  })

  self._commit_view:set_lines(lines)
  self._commit_view:set_cursor({ 1, 0 })
  self._commit_view:start_insert()
end

function StatusDiffView:open_file()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end

  local filename = entry.status.filename
  local mark = self._diff_component and self._diff_component:get_current_mark_under_cursor()

  self:destroy()
  event.await()

  local lnum = mark and mark.top_relative or nil
  navigation.open_file(filename, lnum, 'center')
end

function StatusDiffView:_handle_file_selection_change(item)
  if self._refreshing then return end
  if self._skip_on_move then
    self._skip_on_move = false
    return
  end
  if self._destroyed then return end

  if not item then
    console.warn('[StatusDiffView] file selection changed called with nil item')
    return
  end

  self._diff_gen = self._diff_gen + 1
  local gen = self._diff_gen

  local entry = item.entry or item

  self._diff_component:reset()

  if not self:_is_valid_entry(entry) then
    self._diff_component:set_props({
      diff = vim.NIL,
      filename = vim.NIL,
      filetype = vim.NIL,
    })
    return
  end

  local repo, repo_err = repository.current()
  if repo_err then
    console.debug.error(repo_err)
    return
  end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if err then
    console.debug.error(err)
    return
  end

  if self._diff_gen ~= gen then return end

  if not diff_data then
    self._diff_component:set_props({
      diff = vim.NIL,
      filename = vim.NIL,
      filetype = vim.NIL,
    })
    return
  end

  if self._diff_component then
    local has_content = diff_data.marks and #diff_data.marks > 0

    if has_content then
      self._diff_component:set_props({
        diff = diff_data,
        filename = entry.status.filename,
        filetype = entry.status.filetype or 'text',
      })

      local target_hunk = 1
      if self._initial_cursor_lnum then
        local cursor_lnum = self._initial_cursor_lnum
        self._initial_cursor_lnum = nil
        local hunks = self._diff_component:get_hunks()
        for i, hunk in ipairs(hunks) do
          if cursor_lnum >= hunk.top and cursor_lnum <= hunk.bot then
            target_hunk = i
            break
          end
        end
      end

      if self._diff_component.call then
        self._diff_component:call(function()
          self._diff_component:move_to_hunk(target_hunk, self:get_hunk_alignment(), self:get_hunk_alignment_offset())
        end)
      end
    else
      self._diff_component:set_props({
        diff = vim.NIL,
        filename = vim.NIL,
        filetype = vim.NIL,
      })
    end
  end
end

function StatusDiffView:stage_all()
  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end
  local _, stage_err = repo:stage_all()
  if stage_err then
    console.debug.error(stage_err)
    return
  end

  self:refresh_and_navigate(function()
    if not self:_move_to_first_entry_of_type('staged') then self:_move_to_first_entry() end
  end)
end

function StatusDiffView:unstage_all()
  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end
  local _, unstage_err = repo:unstage_all()
  if unstage_err then
    console.debug.error(unstage_err)
    return
  end

  self:refresh_and_navigate(function()
    if not self:_move_to_first_entry_of_type('unstaged') then self:_move_to_first_entry() end
  end)
end

function StatusDiffView:reset_all()
  event.await()
  if not self:_confirm('Are you sure you want to discard all changes? (y/N) ') then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end
  local _, reset_err = repo:reset('.')
  if reset_err then
    console.debug.error(reset_err)
    return
  end

  self._refreshing = true
  local has_data = self:refresh_data()
  if has_data == false then
    self._refreshing = false
    self:destroy()
    return
  end

  self:_move_to_first_entry()
  self._refreshing = false
  self:_refresh_diff()
end

function StatusDiffView:refresh_data()
  event.await()

  local repo, err = repository.current()
  if err then return end

  local data, status_err = repo:status(self._opts)
  if status_err then
    console.debug.error(status_err)
    return
  end

  if not data or utils.object.is_empty(data.entries) then return false end

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
  end

  self._tree_component:set_list(file_groups)
end

function StatusDiffView:setup_keymaps()
  local diff_keymaps = status_diff_view_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  self:_setup_quit_keymap()

  -- Hunk-level operations on diff component
  local stage_hunk_key = keymap.get_key(diff_keymaps.stage_hunk)
  if stage_hunk_key then
    self:_register_keymap(self._diff_component, 'n', stage_hunk_key, function()
      self:stage_hunk()
    end)
  end

  local unstage_hunk_key = keymap.get_key(diff_keymaps.unstage_hunk)
  if unstage_hunk_key then
    self:_register_keymap(self._diff_component, 'n', unstage_hunk_key, function()
      self:unstage_hunk()
    end)
  end

  local reset_hunk_key = keymap.get_key(diff_keymaps.reset_hunk)
  if reset_hunk_key then
    self:_register_keymap(self._diff_component, 'n', reset_hunk_key, function()
      self:reset_hunk()
    end)
  end

  -- File-level operations on diff component
  local stage_file_key = keymap.get_key(diff_keymaps.stage)
  if stage_file_key then
    self:_register_keymap(self._diff_component, 'n', stage_file_key, function()
      self:stage_entry({ follow_same_file = true })
    end)
  end

  local unstage_file_key = keymap.get_key(diff_keymaps.unstage)
  if unstage_file_key then
    self:_register_keymap(self._diff_component, 'n', unstage_file_key, function()
      self:unstage_entry({ follow_same_file = true })
    end)
  end

  local reset_file_key = keymap.get_key(diff_keymaps.reset)
  if reset_file_key then
    self:_register_keymap(self._diff_component, 'n', reset_file_key, function()
      self:reset_entry()
    end)
  end

  self:_setup_hunk_navigation_keymaps()

  local down_key = keymap.get_key(hunks_keymaps.down)
  if down_key then
    local down_fn = event.async(function()
      self:hunk_down()
    end)
    if self._tree_component:is_valid() then self._tree_component:set_keymap({ mode = 'n', key = down_key }, down_fn) end
  end

  local up_key = keymap.get_key(hunks_keymaps.up)
  if up_key then
    local up_fn = event.async(function()
      self:hunk_up()
    end)
    if self._tree_component:is_valid() then self._tree_component:set_keymap({ mode = 'n', key = up_key }, up_fn) end
  end

  local stash_key = keymap.get_key(diff_keymaps.stash)
  if stash_key then
    local stash_fn = self:_make_debounced(function()
      local _, err = self._repo:stash_add()
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('Changes stashed')
      self._refreshing = true
      local has_data = self:refresh_data()
      if has_data == false then
        self._refreshing = false
        self:destroy()
        return
      end
      self._refreshing = false
    end)
    self._diff_component:set_keymap({ mode = 'n', key = stash_key }, stash_fn)
    if self._tree_component:is_valid() then
      self._tree_component:set_keymap({ mode = 'n', key = stash_key }, stash_fn)
    end
  end

  self:_register_keymap(self._diff_component, 'n', '<enter>', function()
    self:open_file()
  end)
end

function StatusDiffView:_create_view(data)
  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return false
  end

  self._repo = repo

  local file_groups = {}
  for _, entry in ipairs(data.entries) do
    file_groups[#file_groups + 1] = {
      open = true,
      value = entry.title,
      metadata = {},
      items = entry.entries,
    }
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

  local stage_file_fn, stage_file_cleanup = event.debounce_async(function()
    self:stage_entry()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, stage_file_cleanup)

  local unstage_file_fn, unstage_file_cleanup = event.debounce_async(function()
    self:unstage_entry()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, unstage_file_cleanup)

  local reset_file_fn, reset_file_cleanup = event.debounce_async(function()
    self:reset_entry()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, reset_file_cleanup)

  local stage_all_fn, stage_all_cleanup = event.debounce_async(function()
    self:stage_all()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, stage_all_cleanup)

  local unstage_all_fn, unstage_all_cleanup = event.debounce_async(function()
    self:unstage_all()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, unstage_all_cleanup)

  local reset_all_fn, reset_all_cleanup = event.debounce_async(function()
    self:reset_all()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, reset_all_cleanup)

  self._tree_component = TreeComponent({
    list = file_groups,
    title = '',
    width = 50,
    focus = true,
    keymaps = tree_keymaps,
    keymap_handlers = {
      commit = function()
        self:commit()
      end,
      reset_file = reset_file_fn,
      stage_file = stage_file_fn,
      unstage_file = unstage_file_fn,
      stage_all = stage_all_fn,
      unstage_all = unstage_all_fn,
      reset_all = reset_all_fn,
    },
  })

  self._tree_component:set_on_enter(function(item)
    if item and item.entry and item.entry.status then self:open_file() end
  end)

  local on_move_fn, on_move_cleanup = event.debounce_trailing_async(function(item)
    self:_handle_file_selection_change(item)
  end, self.DEBOUNCE_MS)

  table.insert(self._debounce_cleanups, on_move_cleanup)
  self._tree_component:set_on_move(on_move_fn)

  self._diff_component = self:_create_diff_component({
    diff = nil,
    filename = nil,
    filetype = nil,
  }, self._opts.layout_type or self.LAYOUT_UNIFIED)

  event.await()
  self:_render(LayoutSpec.screen({
    LayoutSpec.horizontal({
      LayoutSpec.view(self._tree_component, { width = '30%' }),
      LayoutSpec.view(self._diff_component, { flex = 1 }),
    }),
  }))

  self:setup_keymaps()

  self._initial_cursor_lnum = data.cursor_lnum

  if self._tree_component and self._tree_component:is_valid() then
    self._tree_component:focus()

    local moved = false
    if data.current_filename then
      moved = self._tree_component:move_to(function(status, entry_type)
        return status.filename == data.current_filename and entry_type == 'unstaged'
      end)
      if not moved then
        moved = self._tree_component:move_to(function(status)
          return status.filename == data.current_filename
        end)
      end
    end

    if not moved then
      self._initial_cursor_lnum = nil
      self._tree_component:move_to(function(status)
        return status ~= nil
      end)
    end
  end

  return true
end

function StatusDiffView:on_git_change()
  if self._refreshing then return end

  local entry = self:get_current_entry()
  local filename = entry and entry.status and entry.status.filename
  local entry_type = entry and entry.type

  local has_data = self:refresh_data()

  if has_data == false then
    self:destroy()
    return
  end

  if filename then
    -- Try exact match (same section) first, then any section
    local found_type = nil
    self._tree_component:each_entry(function(status, et)
      if status.filename == filename then
        if et == entry_type then
          found_type = entry_type
        elseif not found_type then
          found_type = et
        end
      end
    end)

    if found_type then
      self:move_to_entry(filename, found_type)
      self:_refresh_diff()
    else
      self:_move_to_first_entry()
      self:_refresh_diff()
    end
  else
    self:_move_to_first_entry()
    self:_refresh_diff()
  end
end

function StatusDiffView:destroy()
  if self:is_destroyed() then return end

  self:_close_commit_split()

  View.destroy(self)
end

return StatusDiffView
