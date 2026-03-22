local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local utils = lazy('vgit.core.utils')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local navigation = lazy('vgit.core.navigation')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local display_service = lazy('vgit.ui.display_service')
local file_diff_view_setting = lazy('vgit.settings.file_diff_view')

local FileDiffView = View:extend()

FileDiffView.DEBOUNCE_MS = 100
FileDiffView.LAYOUT_SPLIT = 'split'
FileDiffView.LAYOUT_UNIFIED = 'unified'

function FileDiffView:constructor()
  local instance = View.constructor(self)
  instance._opts = {
    filename = nil,
    old_filename = nil,
    is_staged = false,
    is_live = true,
    cursor_line = false,
    layout_type = self.LAYOUT_UNIFIED,
  }
  instance._data = nil
  instance._diff_component = nil
  return instance
end

function FileDiffView:get_navigatable_component()
  return self._diff_component
end

function FileDiffView:get_hunk_alignment()
  return file_diff_view_setting:get('hunk_alignment')
end

function FileDiffView:get_hunk_alignment_offset()
  return file_diff_view_setting:get('hunk_alignment_offset') or 0
end

function FileDiffView:_refresh_diff_data()
  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local current_layout_type = scene_setting:get('diff_preference') or FileDiffView.LAYOUT_UNIFIED

  local diff_spec
  local index = repo:index()

  if self._opts.is_staged then
    diff_spec = {
      type = 'range',
      filename = self._opts.filename,
      old_filename = self._opts.old_filename,
      from = 'HEAD',
      to = 'index',
      layout_type = current_layout_type,
      hunks = index:staged_hunks(self._opts.filename),
    }
  else
    diff_spec = {
      type = 'range',
      filename = self._opts.filename,
      from = 'index',
      to = 'disk',
      layout_type = current_layout_type,
      hunks = index:unstaged_hunks(self._opts.filename),
    }
  end

  local diff, diff_err = repo:diff(diff_spec)
  if diff_err then
    console.debug.error(diff_err)
    return
  end
  if not diff then return end

  return {
    diff = diff,
    filename = self._opts.filename,
    filetype = fs.detect_filetype(self._opts.filename),
    layout_type = current_layout_type,
    is_staged = self._opts.is_staged,
  }
end

function FileDiffView:_process_file_data(data)
  self._opts = utils.object.defaults({
    filename = data.filename,
    old_filename = data.old_filename,
    is_staged = data.is_staged,
    is_live = data.is_live,
    cursor_line = data.cursor_line,
    layout_type = data.layout_type,
  }, self._opts)

  self._data = data

  local diff_data = {
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
    target_hunk_index = data.target_hunk_index,
  }

  return self:_create_view(diff_data)
end

function FileDiffView:create(data)
  if not data then
    console.error('[FileDiffView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    console.error('[FileDiffView] Expected table, got ' .. type(data))
    return false
  end

  if not data.diff or utils.object.is_empty(data.diff) then
    console.error('[FileDiffView] Invalid file data: missing or empty diff')
    return false
  end
  if not data.filename or data.filename:match('^%s*$') then
    console.error('[FileDiffView] Invalid file data: missing or empty filename')
    return false
  end

  if data.filetype and type(data.filetype) ~= 'string' then
    console.warn('[FileDiffView] Invalid filetype, using default')
    return false
  end

  return self:_process_file_data(data)
end

function FileDiffView:_create_view(data)
  local layout_type = self._opts.layout_type or self.LAYOUT_UNIFIED
  self._diff_component = self:_create_diff_component({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  }, layout_type)

  event.await()
  self:_render(LayoutSpec.screen({
    LayoutSpec.view(self._diff_component, { flex = 1 }),
  }))

  local target_hunk = 1

  if data.target_hunk_index then
    target_hunk = data.target_hunk_index
  elseif not self._opts.cursor_line then
    local lnum = navigation.get_current_lnum()
    target_hunk = self._diff_component:get_relative_mark_index(lnum)
  end

  self._diff_component:move_to_hunk(target_hunk, self:get_hunk_alignment(), self:get_hunk_alignment_offset())

  self:setup_keymaps()

  return true
end

function FileDiffView:_refresh_diff(opts)
  opts = opts or {}
  event.await()

  if not self._diff_component or not self._diff_component:is_valid() then return false end

  local data = self:_refresh_diff_data()
  if not data then return false end

  if not self._diff_component or not self._diff_component:is_valid() then return false end
  self._diff_component:set_props({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  })

  if opts.hunk_index then
    self._diff_component:move_to_hunk(opts.hunk_index, self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  end

  return true
end

function FileDiffView:toggle_view()
  event.await()
  if not self._opts.filename then return end

  self._opts.is_staged = not self._opts.is_staged
  if not self:_refresh_diff({ hunk_index = 1 }) then self._opts.is_staged = not self._opts.is_staged end
end

function FileDiffView:reset_current()
  if self._opts.is_staged then return end

  event.await()
  if not self:_confirm('Are you sure you want to discard all unstaged changes? (y/N) ') then return end

  local filename = self._opts.filename
  if not filename then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end
  local _, reset_err = repo:reset(filename)
  if reset_err then
    console.debug.error(reset_err)
    return
  end

  self:_refresh_diff()
end

function FileDiffView:open_file()
  event.await()
  local mark = self._diff_component:get_current_mark_under_cursor()
  if not mark then return end

  local filename = self._opts.filename
  if not filename then return end

  self:destroy()
  event.await()

  navigation.open_file(filename, mark.top_relative, 'center')
end

function FileDiffView:stage_hunk()
  event.await()

  local filename = self._opts.filename
  if not filename then return end
  if self._opts.is_staged then return end

  local hunk, index = self._diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, stage_err = repo:stage_hunk(filename, hunk)
  if stage_err then
    console.debug.error(stage_err)
    return
  end

  self:_refresh_diff({ hunk_index = index })

  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk({ index = idx, count = count }) end
end

function FileDiffView:unstage_hunk()
  event.await()

  local filename = self._opts.filename
  if not filename then return end
  if not self._opts.is_staged then return end

  local hunk, index = self._diff_component:get_hunk_under_cursor()
  if not hunk then return end

  local repo, err = repository.current()
  if err then
    console.debug.error(err)
    return
  end

  local _, unstage_err = repo:unstage_hunk(filename, hunk)
  if unstage_err then
    console.debug.error(unstage_err)
    return
  end

  self:_refresh_diff({ hunk_index = index })

  local idx, count = self:get_current_mark_index()
  if idx then statusline.set_hunk({ index = idx, count = count }) end
end

function FileDiffView:stage_current()
  if self._opts.is_staged then return end

  event.await()
  local filename = self._opts.filename
  if not filename then return end

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

  self:_refresh_diff()
end

function FileDiffView:unstage_current()
  if not self._opts.is_staged then return end

  event.await()
  local filename = self._opts.filename
  if not filename then return end

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

  self:_refresh_diff()
end

function FileDiffView:show_blame_view()
  local filename = self._opts.filename
  if not filename then return end
  display_service.show_blame_view_for_file(filename)
end

function FileDiffView:setup_keymaps()
  local diff_keymaps = file_diff_view_setting:get('keymaps')

  self:_setup_quit_keymap()
  self:_setup_hunk_navigation_keymaps()

  -- Only set up staging/unstaging keymaps for live diffs (not historical)
  if self._opts.is_live then
    local stage_key = keymap.get_key(diff_keymaps.stage)
    if stage_key then
      self:_register_keymap(self._diff_component, 'n', stage_key, function()
        self:stage_current()
      end)
    end

    local unstage_key = keymap.get_key(diff_keymaps.unstage)
    if unstage_key then
      self:_register_keymap(self._diff_component, 'n', unstage_key, function()
        self:unstage_current()
      end)
    end

    local reset_key = keymap.get_key(diff_keymaps.reset)
    if reset_key then
      self:_register_keymap(self._diff_component, 'n', reset_key, function()
        self:reset_current()
      end)
    end

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

    local toggle_view_key = keymap.get_key(diff_keymaps.toggle_view)
    if toggle_view_key then
      self:_register_keymap(self._diff_component, 'n', toggle_view_key, function()
        self:toggle_view()
      end)
    end
  end

  self:_register_keymap(self._diff_component, 'n', '<enter>', function()
    self:open_file()
  end)
  self:_register_keymap(self._diff_component, 'n', 'b', function()
    self:show_blame_view()
  end)
end

return FileDiffView
