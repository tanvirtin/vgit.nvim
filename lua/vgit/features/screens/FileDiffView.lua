local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local fs = lazy('vgit.core.fs')
local event = lazy('vgit.core.event')
local utils = lazy('vgit.core.utils')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local navigation = lazy('vgit.core.navigation')
local repository = lazy('vgit.git.repository')
local hunks_setting = lazy('vgit.settings.hunks')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local display_service = lazy('vgit.ui.display_service')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local file_diff_view_setting = lazy('vgit.settings.file_diff_view')
local SplitDiffComponent = lazy('vgit.ui.components.SplitDiffComponent')

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

function FileDiffView:get_hunk_alignment()
  return file_diff_view_setting:get('hunk_alignment')
end

function FileDiffView:get_hunk_alignment_offset()
  return file_diff_view_setting:get('hunk_alignment_offset') or 0
end

function FileDiffView:get_current_mark_index()
  return navigation.get_mark_index(self._diff_component:get_marks(), self._diff_component:get_lnum())
end

function FileDiffView:hunk_up()
  if not self._diff_component or not self._diff_component:is_valid() then return end
  self._diff_component:hunk_up(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  local index, count = self:get_current_mark_index()
  if index then statusline.set_hunk({ index = index, count = count }) end
end

function FileDiffView:hunk_down()
  if not self._diff_component or not self._diff_component:is_valid() then return end
  self._diff_component:hunk_down(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
  local index, count = self:get_current_mark_index()
  if index then statusline.set_hunk({ index = index, count = count }) end
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

  return self:_create_file_view(diff_data)
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

function FileDiffView:create_diff_component(opts)
  opts = opts or {}
  local layout_type = self._opts.layout_type or self.LAYOUT_UNIFIED

  local props = {
    diff = opts.diff,
    filename = opts.filename,
    filetype = opts.filetype or 'text',
  }

  if layout_type == self.LAYOUT_SPLIT then return SplitDiffComponent(props) end
  return DiffComponent(props)
end

function FileDiffView:_create_file_view(data)
  self._diff_component = self:create_diff_component({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(LayoutSpec.screen({
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

function FileDiffView:_reconcile(opts)
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
  if not self:_reconcile({ hunk_index = 1 }) then self._opts.is_staged = not self._opts.is_staged end
end

function FileDiffView:reset_current()
  if self._opts.is_staged then return end

  event.await()
  local decision = console.input('Are you sure you want to discard all unstaged changes? (y/N) ')
  if not decision then return end
  decision = decision:lower()
  if decision ~= 'yes' and decision ~= 'y' then return end

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

  self:_reconcile()
end

function FileDiffView:enter_view()
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

  self:_reconcile({ hunk_index = index })

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

  self:_reconcile({ hunk_index = index })

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

  self:_reconcile()
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

  self:_reconcile()
end

function FileDiffView:show_blame_view()
  local filename = self._opts.filename
  if not filename then return end
  display_service.show_blame_view_for_file(filename)
end

function FileDiffView:setup_keymaps()
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = file_diff_view_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = keymap.get_key(scene_keymaps.quit)
    if quit_key then
      self._diff_component:set_keymap({
        mode = 'n',
        key = quit_key,
      }, function()
        self._component_manager:destroy()
      end)
    end
  end

  local up_key = keymap.get_key(hunks_keymaps.up)
  if up_key then
    local up_fn = event.async(function()
      self:hunk_up()
    end)
    self._diff_component:set_keymap({
      mode = 'n',
      key = up_key,
    }, up_fn)
  end

  local down_key = keymap.get_key(hunks_keymaps.down)
  if down_key then
    local down_fn = event.async(function()
      self:hunk_down()
    end)
    self._diff_component:set_keymap({
      mode = 'n',
      key = down_key,
    }, down_fn)
  end

  -- Only set up staging/unstaging keymaps for live diffs (not historical)
  if self._opts.is_live then
    local stage_key = keymap.get_key(diff_keymaps.stage)
    if stage_key then
      local stage_fn, stage_cleanup = event.debounce_async(function()
        self:stage_current()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, stage_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = stage_key,
      }, stage_fn)
    end

    local unstage_key = keymap.get_key(diff_keymaps.unstage)
    if unstage_key then
      local unstage_fn, unstage_cleanup = event.debounce_async(function()
        self:unstage_current()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, unstage_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = unstage_key,
      }, unstage_fn)
    end

    local reset_key = keymap.get_key(diff_keymaps.reset)
    if reset_key then
      local reset_fn, reset_cleanup = event.debounce_async(function()
        self:reset_current()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, reset_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = reset_key,
      }, reset_fn)
    end

    local stage_hunk_key = keymap.get_key(diff_keymaps.stage_hunk)
    if stage_hunk_key then
      local stage_hunk_fn, stage_hunk_cleanup = event.debounce_async(function()
        self:stage_hunk()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, stage_hunk_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = stage_hunk_key,
      }, stage_hunk_fn)
    end

    local unstage_hunk_key = keymap.get_key(diff_keymaps.unstage_hunk)
    if unstage_hunk_key then
      local unstage_hunk_fn, unstage_hunk_cleanup = event.debounce_async(function()
        self:unstage_hunk()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, unstage_hunk_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = unstage_hunk_key,
      }, unstage_hunk_fn)
    end

    local toggle_view_key = keymap.get_key(diff_keymaps.toggle_view)
    if toggle_view_key then
      local toggle_view_fn, toggle_view_cleanup = event.debounce_async(function()
        self:toggle_view()
      end, self.DEBOUNCE_MS)
      table.insert(self._debounce_cleanups, toggle_view_cleanup)
      self._diff_component:set_keymap({
        mode = 'n',
        key = toggle_view_key,
      }, toggle_view_fn)
    end
  end

  local enter_fn, enter_cleanup = event.debounce_async(function()
    self:enter_view()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, enter_cleanup)
  self._diff_component:set_keymap({
    mode = 'n',
    key = '<enter>',
  }, enter_fn)

  local blame_fn, blame_cleanup = event.debounce_async(function()
    self:show_blame_view()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, blame_cleanup)
  self._diff_component:set_keymap({
    mode = 'n',
    key = 'b',
  }, blame_fn)
end

return FileDiffView
