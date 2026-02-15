local lazy = require('vgit.core.lazy')
local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local Layout = lazy('vgit.ui.Layout')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local Window = lazy('vgit.core.Window')
local console = lazy('vgit.core.console')
local statusline = lazy('vgit.core.statusline_state')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local hunks_setting = lazy('vgit.settings.hunks')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local view_utils = lazy('vgit.features.screens.view_utils')
local TreeComponent = lazy('vgit.ui.components.TreeComponent')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local status_diff_view_setting = lazy('vgit.settings.status_diff_view')
local SplitDiffComponent = lazy('vgit.ui.components.SplitDiffComponent')

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
    diff_component = nil,
    tree_component = nil,
    component_manager = nil,
    commit_buf = nil,
    commit_win = nil,
    debounce_cleanups = {},
    _refreshing = false,
    _skip_on_move = false,
  }
end

function StatusDiffView:_is_valid_entry(entry)
  if not entry then return false end
  if not entry.status then return false end
  if not entry.status.filename or type(entry.status.filename) ~= 'string' then return false end
  return true
end

function StatusDiffView:get_current_entry()
  if not self.tree_component then return nil end
  return self.tree_component:get_selected_entry()
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
  return status_diff_view_setting:get('hunk_alignment')
end

function StatusDiffView:hunk_down()
  if not self.diff_component or not self.diff_component:is_valid() then return end

  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = self:get_hunk_alignment()

  if not current_index or total_hunks == 0 or current_index >= total_hunks then
    -- At last hunk or no hunks - move to next file
    local item = self:move_to_next_file()
    if not item then return end
    self:_update_diff_component()
    if self.diff_component and self.diff_component:is_valid() then
      self.diff_component:move_to_hunk(1, hunk_alignment)
    end
  else
    self.diff_component:hunk_down(hunk_alignment)
  end

  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk(idx, count) end
end

function StatusDiffView:hunk_up()
  if not self.diff_component or not self.diff_component:is_valid() then return end

  local current_index, total_hunks = self:get_current_mark_index()
  local hunk_alignment = self:get_hunk_alignment()

  if not current_index or total_hunks == 0 or current_index <= 1 then
    -- At first hunk or no hunks - move to previous file's last hunk
    local item = self:move_to_prev_file()
    if not item then return end
    self:_update_diff_component()
    -- Pass 0 to go to last hunk
    if self.diff_component and self.diff_component:is_valid() then
      self.diff_component:move_to_hunk(0, hunk_alignment)
    end
  else
    self.diff_component:hunk_up(hunk_alignment)
  end

  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk(idx, count) end
end

function StatusDiffView:reset_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local hunk, hunk_index = self.diff_component:get_hunk_under_cursor()
  if not hunk then return end

  -- Confirmation prompt
  local decision = console.input('Are you sure you want to discard this hunk? (y/N) ')
  if not decision then return end
  decision = decision:lower()
  if decision ~= 'y' and decision ~= 'yes' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then return end

  local _, reset_err = repo:reset_hunk(filename, hunk)
  if reset_err then
    console.debug.error(string.format('[StatusDiffView] reset_hunk failed: %s', reset_err))
    return
  end

  self._refreshing = true
  self:refresh_data()

  local still_has_entries = false
  self.tree_component:each_entry(function(status, et)
    if et == 'unstaged' and status.filename == filename then still_has_entries = true end
  end)

  if still_has_entries then
    self:move_to_entry(filename, 'unstaged')
    self._refreshing = false
    self:_update_diff_component()
    self:restore_hunk_position(hunk_index)
  else
    if next_file then
      self:move_to_entry(next_file, 'unstaged')
    elseif not self:_move_to_first_entry_of_type('unstaged') then
      if not self:_move_to_first_entry_of_type('staged') then
        self:_move_to_first_entry()
      end
    end
    self._refreshing = false
    self:_update_diff_component(1)
  end

  self._skip_on_move = true
  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk(idx, count) end
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
  local marks = self.diff_component:get_marks()
  if #marks > 0 then
    local target = math.min(hunk_index, #marks)
    self.diff_component:move_to_hunk(target, self:get_hunk_alignment())
  end
end

function StatusDiffView:_move_to_first_entry()
  self.tree_component:move_to(function(status) return status ~= nil end)
end

function StatusDiffView:_move_to_first_entry_of_type(target_type)
  return self.tree_component:move_to(function(status, entry_type)
    return status ~= nil and entry_type == target_type
  end) ~= nil
end

function StatusDiffView:refresh_and_navigate(navigate_fn)
  self._refreshing = true
  self:refresh_data()
  navigate_fn()
  self._refreshing = false
  self:_update_diff_component()
end


function StatusDiffView:move_to_next_file()
  if not self.tree_component or not self.tree_component:is_valid() then return nil end

  local current_lnum = self.tree_component:get_lnum()
  local count = self.tree_component:get_line_count()

  -- Find next file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum + offset
    if target_lnum > count then target_lnum = target_lnum - count end

    local item = self.tree_component:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      self.tree_component:set_lnum(target_lnum)
      return item
    end
  end

  return nil
end

function StatusDiffView:move_to_prev_file()
  if not self.tree_component or not self.tree_component:is_valid() then return nil end

  local current_lnum = self.tree_component:get_lnum()
  local count = self.tree_component:get_line_count()

  -- Find previous file entry (skip folders)
  for offset = 1, count do
    local target_lnum = current_lnum - offset
    if target_lnum < 1 then target_lnum = target_lnum + count end

    local item = self.tree_component:get_list_item(target_lnum)
    if item and item.entry and item.entry.status then
      self.tree_component:set_lnum(target_lnum)
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
  if self.opts.layout_type then opts.layout_type = self.opts.layout_type end

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
    current_filename = data.current_filename,
    cursor_lnum = data.cursor_lnum,
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
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return false end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return false end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return false end

  self.diff_component:set_props({
    diff = diff_data,
    filename = entry.status.filename,
    filetype = entry.status.filetype,
  })

  if hunk_index then self.diff_component:move_to_hunk(hunk_index, self:get_hunk_alignment()) end

  return true
end

function StatusDiffView:stage_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local filename = entry.status.filename

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

  self._refreshing = true
  self:refresh_data()

  local still_has_entries = false
  self.tree_component:each_entry(function(status, et)
    if et == 'unstaged' and status.filename == filename then still_has_entries = true end
  end)

  if still_has_entries then
    self:move_to_entry(filename, 'unstaged')
    self._refreshing = false
    self:_update_diff_component()
    self:restore_hunk_position(hunk_index)
  else
    if not self:_move_to_first_entry_of_type('unstaged') then
      if not self.tree_component:move_to(function(s, et) return s.filename == filename and et == 'staged' end) then
        if not self:_move_to_first_entry_of_type('staged') then
          self:_move_to_first_entry()
        end
      end
    end
    self._refreshing = false
    self:_update_diff_component(1)
  end

  self._skip_on_move = true
  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk(idx, count) end
end

function StatusDiffView:unstage_hunk()
  event.await()

  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'staged' then return end

  local filename = entry.status.filename

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

  self._refreshing = true
  self:refresh_data()

  local still_has_entries = false
  self.tree_component:each_entry(function(status, et)
    if et == 'staged' and status.filename == filename then still_has_entries = true end
  end)

  if still_has_entries then
    self:move_to_entry(filename, 'staged')
    self._refreshing = false
    self:_update_diff_component()
    self:restore_hunk_position(hunk_index)
  else
    if not self:_move_to_first_entry_of_type('staged') then
      if not self.tree_component:move_to(function(s, et) return s.filename == filename and et == 'unstaged' end) then
        if not self:_move_to_first_entry_of_type('unstaged') then
          self:_move_to_first_entry()
        end
      end
    end
    self._refreshing = false
    self:_update_diff_component(1)
  end

  self._skip_on_move = true
  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk(idx, count) end
end

function StatusDiffView:stage_entry()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then return end
  repo:stage_file(filename)

  self:refresh_and_navigate(function()
    if next_file then
      self:move_to_entry(next_file, 'unstaged')
    elseif not self:_move_to_first_entry_of_type('unstaged') then
      if not self:_move_to_first_entry_of_type('staged') then
        self:_move_to_first_entry()
      end
    end
  end)
end

function StatusDiffView:unstage_entry()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'staged' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'staged')

  local repo, err = repository.current()
  if err then return end
  repo:unstage_file(filename)

  self:refresh_and_navigate(function()
    if next_file then
      self:move_to_entry(next_file, 'staged')
    elseif not self:_move_to_first_entry_of_type('staged') then
      if not self:_move_to_first_entry_of_type('unstaged') then
        self:_move_to_first_entry()
      end
    end
  end)
end

function StatusDiffView:reset_entry()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end

  event.await()
  local decision = console.input('Are you sure you want to discard changes? (y/N) ')
  if not decision then return end
  decision = decision:lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  local filename = entry.status.filename
  local next_file = self:find_next_file(filename, 'unstaged')

  local repo, err = repository.current()
  if err then return end
  repo:reset(filename)

  self:refresh_and_navigate(function()
    if next_file then
      self:move_to_entry(next_file, 'unstaged')
    elseif not self:_move_to_first_entry_of_type('unstaged') then
      if not self:_move_to_first_entry_of_type('staged') then
        self:_move_to_first_entry()
      end
    end
  end)
end

function StatusDiffView:stage_entry_from_diff()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'unstaged' then return end

  local filename = entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:stage_file(filename)

  self:refresh_and_navigate(function()
    if not self.tree_component:move_to(function(s, et) return s.filename == filename and et == 'staged' end) then
      if not self:_move_to_first_entry_of_type('staged') then
        self:_move_to_first_entry()
      end
    end
  end)
end

function StatusDiffView:unstage_entry_from_diff()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end
  if entry.type ~= 'staged' then return end

  local filename = entry.status.filename

  local repo, err = repository.current()
  if err then return end
  repo:unstage_file(filename)

  self:refresh_and_navigate(function()
    if not self.tree_component:move_to(function(s, et) return s.filename == filename and et == 'unstaged' end) then
      if not self:_move_to_first_entry_of_type('unstaged') then
        self:_move_to_first_entry()
      end
    end
  end)
end

function StatusDiffView:reset_entry_from_diff()
  self:reset_entry()
end

function StatusDiffView:_is_commit_split_open()
  return self.commit_buf
    and vim.api.nvim_buf_is_valid(self.commit_buf)
    and self.commit_win
    and vim.api.nvim_win_is_valid(self.commit_win)
end

function StatusDiffView:_close_commit_split()
  if self.commit_win and vim.api.nvim_win_is_valid(self.commit_win) then
    vim.api.nvim_win_close(self.commit_win, true)
  end
  if self.commit_buf and vim.api.nvim_buf_is_valid(self.commit_buf) then
    vim.api.nvim_buf_delete(self.commit_buf, { force = true })
  end
  self.commit_buf = nil
  self.commit_win = nil
end

function StatusDiffView:_confirm_commit()
  if not self.commit_buf or not vim.api.nvim_buf_is_valid(self.commit_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(self.commit_buf, 0, -1, false)

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
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local _, err = repo:commit(message)
  if not self:_handle_git_error(err, 'commit') then return end

  console.info('Changes committed successfully')
end

function StatusDiffView:commit()
  event.await()

  if self:_is_commit_split_open() then
    vim.api.nvim_set_current_win(self.commit_win)
    return
  end

  local buf = vim.api.nvim_create_buf(false, true)

  local diff_keymaps = status_diff_view_setting:get('keymaps')
  local confirm_key = self:get_key(diff_keymaps.commit_confirm) or '<C-s>'
  local cancel_key = self:get_key(diff_keymaps.commit_cancel) or 'q'

  local lines = { '' }
  lines[#lines + 1] = '# Press ' .. confirm_key .. ' to confirm, ' .. cancel_key .. ' to cancel.'
  lines[#lines + 1] = '# Lines starting with # will be ignored.'

  local refs = self.repo:refs()
  if refs then
    local branch = refs:current_branch()
    if branch then
      lines[#lines + 1] = '#'
      lines[#lines + 1] = '# On branch ' .. branch
    end
  end

  if self.data and self.data.entries then
    for _, group in ipairs(self.data.entries) do
      if group.entries and #group.entries > 0 then
        lines[#lines + 1] = '#'
        lines[#lines + 1] = '# ' .. group.title .. ':'
        for _, entry in ipairs(group.entries) do
          if entry.status then lines[#lines + 1] = '#   ' .. entry.status.value .. ' ' .. entry.status.filename end
        end
      end
    end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  vim.cmd('botright 20split')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.api.nvim_set_option_value('buftype', 'nofile', { buf = buf })
  vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
  vim.api.nvim_set_option_value('filetype', 'gitcommit', { buf = buf })

  vim.api.nvim_set_option_value('number', false, { win = win })
  vim.api.nvim_set_option_value('relativenumber', false, { win = win })
  vim.api.nvim_set_option_value('signcolumn', 'no', { win = win })
  vim.api.nvim_set_option_value('wrap', true, { win = win })
  vim.api.nvim_set_option_value('cursorline', true, { win = win })

  self.commit_buf = buf
  self.commit_win = win

  vim.keymap.set(
    { 'n', 'i' },
    confirm_key,
    event.async(function()
      self:_confirm_commit()
    end),
    { buffer = buf, desc = 'Confirm commit' }
  )

  vim.keymap.set('n', cancel_key, function()
    self:_close_commit_split()
    console.info('Commit cancelled')
  end, { buffer = buf, desc = 'Cancel commit' })

  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = buf,
    once = true,
    callback = function()
      self.commit_buf = nil
      self.commit_win = nil
    end,
  })

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  vim.cmd('startinsert')
end

function StatusDiffView:open_file()
  local entry = self:get_current_entry()
  if not self:_is_valid_entry(entry) then return end

  local filename = entry.status.filename
  local mark = self.diff_component and self.diff_component:get_current_mark_under_cursor()

  self:destroy()
  event.await()
  fs.open(filename)

  if mark then
    Window(0):set_lnum(mark.top_relative):position_cursor('center')
  end
end

function StatusDiffView:_handle_file_selection_change(item)
  if self._refreshing then return end
  if self._skip_on_move then
    self._skip_on_move = false
    return
  end
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
  if not self:_is_valid_entry(entry) then return end

  local repo, repo_err = repository.current()
  if not self:_handle_git_error(repo_err, 'repository.current') then return end

  local diff_data, err = self:_build_entry_diff(entry, repo)
  if not self:_handle_git_error(err, '_build_entry_diff') then return end

  if self.diff_component then
    local has_content = diff_data and diff_data.marks and #diff_data.marks > 0

    if has_content then
      self.diff_component:set_props({
        diff = diff_data,
        filename = entry.status.filename,
        filetype = entry.status.filetype or 'text',
      })

      local target_hunk = 1
      if self._initial_cursor_lnum then
        local cursor_lnum = self._initial_cursor_lnum
        self._initial_cursor_lnum = nil
        local hunks = self.diff_component:get_hunks()
        for i, hunk in ipairs(hunks) do
          if cursor_lnum >= hunk.top and cursor_lnum <= hunk.bot then
            target_hunk = i
            break
          end
        end
      end

      if self.diff_component.call then
        self.diff_component:call(function()
          self.diff_component:move_to_hunk(target_hunk, self:get_hunk_alignment())
        end)
      end
    else
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

  self:refresh_and_navigate(function()
    if not self:_move_to_first_entry_of_type('staged') then
      self:_move_to_first_entry()
    end
  end)
end

function StatusDiffView:unstage_all()
  local repo, err = repository.current()
  if err then return end
  repo:unstage_all()

  self:refresh_and_navigate(function()
    if not self:_move_to_first_entry_of_type('unstaged') then
      self:_move_to_first_entry()
    end
  end)
end

function StatusDiffView:reset_all()
  event.await()
  local decision = console.input('Are you sure you want to discard all changes? (y/N) ')
  if not decision then return end
  decision = decision:lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

  local repo, err = repository.current()
  if err then return end
  repo:reset()

  self._refreshing = true
  local has_data = self:refresh_data()
  if has_data == false then
    self._refreshing = false
    self:destroy()
    return
  end

  self:_move_to_first_entry()
  self._refreshing = false
  self:_update_diff_component()
end

function StatusDiffView:refresh_data()
  event.await()

  local repo, err = repository.current()
  if err then return end

  local data, status_err = repo:status(self.opts)
  if not self:_handle_git_error(status_err, 'status') then return end

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

  self.tree_component:set_list(file_groups)
end

function StatusDiffView:get_key(keymap)
  return view_utils.get_key(keymap)
end

function StatusDiffView:setup_keymaps()
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

  -- File-level operations on diff component
  local stage_file_key = self:get_key(diff_keymaps.stage)
  if stage_file_key then
    local fn, cleanup = event.debounce_async(function()
      self:stage_entry_from_diff()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = stage_file_key,
    }, fn)
  end

  local unstage_file_key = self:get_key(diff_keymaps.unstage)
  if unstage_file_key then
    local fn, cleanup = event.debounce_async(function()
      self:unstage_entry_from_diff()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = unstage_file_key,
    }, fn)
  end

  local reset_file_key = self:get_key(diff_keymaps.reset)
  if reset_file_key then
    local fn, cleanup = event.debounce_async(function()
      self:reset_entry_from_diff()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, cleanup)
    self.diff_component:set_keymap({
      mode = 'n',
      key = reset_file_key,
    }, fn)
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
  table.insert(self.debounce_cleanups, stage_file_cleanup)

  local unstage_file_fn, unstage_file_cleanup = event.debounce_async(function()
    self:unstage_entry()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, unstage_file_cleanup)

  local reset_file_fn, reset_file_cleanup = event.debounce_async(function()
    self:reset_entry()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, reset_file_cleanup)

  local stage_all_fn, stage_all_cleanup = event.debounce_async(function()
    self:stage_all()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, stage_all_cleanup)

  local unstage_all_fn, unstage_all_cleanup = event.debounce_async(function()
    self:unstage_all()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, unstage_all_cleanup)

  local reset_all_fn, reset_all_cleanup = event.debounce_async(function()
    self:reset_all()
  end, self.DEBOUNCE_MS)
  table.insert(self.debounce_cleanups, reset_all_cleanup)

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
      reset_file = reset_file_fn,
      stage_file = stage_file_fn,
      unstage_file = unstage_file_fn,
      stage_all = stage_all_fn,
      unstage_all = unstage_all_fn,
      reset_all = reset_all_fn,
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

  self._initial_cursor_lnum = data.cursor_lnum

  if self.tree_component and self.tree_component:is_valid() then
    self.tree_component:focus()

    local moved = false
    if data.current_filename then
      moved = self.tree_component:move_to(function(status, entry_type)
        return status.filename == data.current_filename and entry_type == 'unstaged'
      end)
      if not moved then
        moved = self.tree_component:move_to(function(status)
          return status.filename == data.current_filename
        end)
      end
    end

    if not moved then
      self._initial_cursor_lnum = nil
      self.tree_component:move_to(function(status)
        return status ~= nil
      end)
    end
  end

  return true
end

function StatusDiffView:emit_cleanup_events()
  self.diff_component:component_will_unmount()
  self.tree_component:component_will_unmount()
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
    self.tree_component:each_entry(function(status, et)
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
      self:_update_diff_component()
    else
      self:_move_to_first_entry()
      self:_update_diff_component()
    end
  end
end

function StatusDiffView:destroy()
  self:_close_commit_split()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
  self:emit_cleanup_events()
  self.component_manager:destroy()
  self.destroyed = true
end

return StatusDiffView
