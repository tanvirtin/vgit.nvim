local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local View = lazy('vgit.ui.View')
local utils = lazy('vgit.core.utils')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local navigation = lazy('vgit.core.navigation')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local display_service = lazy('vgit.ui.display_service')
local LoadingIndicator = lazy('vgit.ui.decorators.LoadingIndicator')
local project_diff_view_setting = lazy('vgit.settings.project_diff_view')
local PatchPreviewComponent = lazy('vgit.ui.components.PatchPreviewComponent')

local ProjectDiffView = View:extend()

ProjectDiffView.DEBOUNCE_MS = 100
ProjectDiffView.FIRST_BATCH_SIZE = 20
ProjectDiffView.BATCH_SIZE = 50
ProjectDiffView.LAYOUT_SPLIT = 'split'
ProjectDiffView.LAYOUT_UNIFIED = 'unified'

local function to_diff_file_entry(file_entry)
  local status = file_entry.status
  if not status or not status.filename then return nil end

  local display_filename = status.filename
  if status.old_filename then display_filename = status.old_filename .. ' -> ' .. status.filename end

  return {
    type = 'diff_file',
    filename = display_filename,
    path = status.filename,
    filetype = status.filetype,
    diff = file_entry.diff,
    original_lines = file_entry.original_lines or {},
    current_lines = file_entry.current_lines or {},
  }
end

function ProjectDiffView:constructor()
  local instance = View.constructor(self)
  instance._data = nil
  instance._repo = nil
  instance._layout_type = nil
  instance._patch_component = nil
  instance._previous_component = nil
  instance._current_component = nil
  instance._diff_file_entries = {}
  instance._line_to_file_map = {}
  instance._sources = {}
  instance._is_multi_repo = false
  instance._update_gen = 0
  instance._loading_indicator = LoadingIndicator()
  return instance
end

function ProjectDiffView:create(data)
  if not data then
    event.await()
    console.error('[ProjectDiffView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    event.await()
    console.error('[ProjectDiffView] Expected table, got ' .. type(data))
    return false
  end

  if not data.entries then
    event.await()
    console.error('[ProjectDiffView] Invalid data: missing entries')
    return false
  end

  if utils.object.is_empty(data.entries) then
    event.await()
    console.info('No changes to display')
    return false
  end

  self._data = data
  return self:_create_view(data)
end

function ProjectDiffView:_get_repo()
  if self._repo then return self._repo, nil end
  return repository.current()
end

function ProjectDiffView:_classify_entries(data)
  local has_staged = false
  local has_unstaged = false
  local conflict_entries = {}

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if not file_entry.diff and not file_entry.range and file_entry.status then
        local entry_type = file_entry.type
        if entry_type == 'unmerged' then
          conflict_entries[#conflict_entries + 1] = file_entry
        elseif entry_type == 'staged' then
          has_staged = true
        else
          has_unstaged = true
        end
      end
    end
  end

  return has_staged, has_unstaged, conflict_entries
end

function ProjectDiffView:_build_line_to_file_map(component, from_lnum, line_to_file_map)
  line_to_file_map = line_to_file_map or {}
  local line_metadata = component:get_all_line_metadata()

  for lnum = from_lnum or 1, #line_metadata do
    local meta = line_metadata[lnum]
    if meta and meta.filename then
      line_to_file_map[lnum] = {
        filename = meta.filename,
        lnum = meta.file_lnum or 1,
      }
    end
  end

  return line_to_file_map
end

function ProjectDiffView:_build_diff_file_entries(repo, data)
  local layout_type = self._layout_type or self.LAYOUT_UNIFIED
  local has_staged, has_unstaged, conflict_entries = self:_classify_entries(data)

  local fetch_funcs = {}
  local staged_fn_idx = nil
  local unstaged_fn_idx = nil

  if has_staged then
    staged_fn_idx = #fetch_funcs + 1
    fetch_funcs[#fetch_funcs + 1] = function()
      return repo:diff({ type = 'range', from = 'HEAD', to = 'index', layout_type = layout_type })
    end
  end

  if has_unstaged then
    unstaged_fn_idx = #fetch_funcs + 1
    fetch_funcs[#fetch_funcs + 1] = function()
      return repo:diff({ type = 'range', to = 'disk', layout_type = layout_type })
    end
  end

  local conflict_start_idx = #fetch_funcs + 1
  for _, entry in ipairs(conflict_entries) do
    local e = entry
    fetch_funcs[#fetch_funcs + 1] = function()
      return { repo:diff({ type = 'conflict', filename = e.status.filename, layout_type = layout_type }) }
    end
  end

  local fetch_results = {}
  if #fetch_funcs > 0 then fetch_results = event.all(fetch_funcs) end

  local all_entries = {}

  if staged_fn_idx then
    local file_diffs = fetch_results[staged_fn_idx]
    if file_diffs then
      for _, fd in ipairs(file_diffs) do
        all_entries[#all_entries + 1] = {
          type = 'diff_file',
          filename = fd.filename,
          path = fd.filename,
          filetype = fd.filetype,
          diff = fd.diff,
          original_lines = fd.original_lines,
          current_lines = fd.current_lines,
        }
      end
    end
  end

  if unstaged_fn_idx then
    local file_diffs = fetch_results[unstaged_fn_idx]
    if file_diffs then
      for _, fd in ipairs(file_diffs) do
        all_entries[#all_entries + 1] = {
          type = 'diff_file',
          filename = fd.filename,
          path = fd.filename,
          filetype = fd.filetype,
          diff = fd.diff,
          original_lines = fd.original_lines,
          current_lines = fd.current_lines,
        }
      end
    end
  end

  for i, entry in ipairs(conflict_entries) do
    local result = fetch_results[conflict_start_idx + i - 1]
    if result and result[1] then
      local diff = result[1]
      all_entries[#all_entries + 1] = {
        type = 'diff_file',
        filename = entry.status.filename,
        path = entry.status.filename,
        filetype = entry.status.filetype,
        diff = diff,
        original_lines = {},
        current_lines = {},
      }
    end
  end

  local precomputed = self:_collect_precomputed_entries(data)
  for _, entry in ipairs(precomputed) do
    all_entries[#all_entries + 1] = entry
  end

  console.debug.info(string.format('[ProjectDiffView] built %d diff_file entries', #all_entries))
  return all_entries
end

function ProjectDiffView:_collect_precomputed_entries(data)
  local entries = {}

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if file_entry.diff then entries[#entries + 1] = to_diff_file_entry(file_entry) end
    end
  end

  return entries
end

function ProjectDiffView:_collect_pending(data)
  local pending = { index = 1 }

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if file_entry.range and file_entry.status then pending[#pending + 1] = file_entry end
    end
  end

  return pending
end

function ProjectDiffView:_load_batch(pending, size)
  local first = pending[pending.index]
  if not first then return {} end

  local files = {}
  local range = first.range
  while #files < size do
    local file_entry = pending[pending.index]
    if not file_entry or file_entry.range.from ~= range.from or file_entry.range.to ~= range.to then break end
    files[#files + 1] = file_entry.status
    pending.index = pending.index + 1
  end

  local file_diffs, err = pending.repo:range_file_diffs(files, {
    from = range.from,
    to = range.to,
    layout_type = self._layout_type,
  })
  if err then
    console.debug.error(err)
    return {}
  end

  local entries = {}
  for _, file_diff in ipairs(file_diffs) do
    entries[#entries + 1] = to_diff_file_entry(file_diff)
  end
  return self:_attach_repo(entries, pending.repo)
end

function ProjectDiffView:_attach_repo(entries, repo)
  if not repo then return entries end

  local prefix = self._is_multi_repo and repo:get_name() .. fs.sep or ''
  for _, entry in ipairs(entries) do
    entry.filename = prefix .. entry.filename:gsub(' %-> ', ' -> ' .. prefix)
    local source = { repo = repo, filename = entry.path or entry.filename }
    self._sources[entry.filename] = source
    self._sources[entry.filename:match('^.+ %-> (.+)$') or entry.filename] = source
  end
  return entries
end

function ProjectDiffView:_next_entries(queue, size)
  if queue.pending and self:_has_pending(queue.pending) then return self:_load_batch(queue.pending, size) end

  if not queue[queue.index] and queue.stream then
    for _, group in ipairs(queue.stream:collect()) do
      if #group.entries > 0 then queue[#queue + 1] = group end
    end
    if not queue[queue.index] then
      event.sleep(5)
      return {}
    end
  end

  local group = queue[queue.index]
  if not group then return {} end
  queue.index = queue.index + 1

  queue.pending = self:_collect_pending(group)
  queue.pending.repo = group.repo
  return self:_attach_repo(self:_build_diff_file_entries(group.repo, group), group.repo)
end

function ProjectDiffView:_has_next(queue)
  if queue.pending and self:_has_pending(queue.pending) then return true end
  return queue[queue.index] ~= nil or (queue.stream ~= nil and not queue.stream:is_done())
end

function ProjectDiffView:_has_pending(pending)
  return pending[pending.index] ~= nil
end

function ProjectDiffView:_load_remaining(queue)
  local gen = self._update_gen

  event.async(function()
    while self:_has_next(queue) do
      event.idle()
      if self:is_destroyed() or gen ~= self._update_gen then return end

      local entries = self:_next_entries(queue, self.BATCH_SIZE)
      if self:is_destroyed() or gen ~= self._update_gen then return end

      if #entries > 0 then self:_append_diff(entries) end
    end
  end)()
end

function ProjectDiffView:get_hunk_alignment()
  return project_diff_view_setting:get('hunk_alignment')
end

function ProjectDiffView:get_hunk_alignment_offset()
  return project_diff_view_setting:get('hunk_alignment_offset') or 0
end

function ProjectDiffView:jump_to_file()
  local component = self:get_navigatable_component()
  if not component or not component:is_valid() then return end

  local lnum = component:get_lnum()
  local file_info = self._line_to_file_map[lnum]

  console.debug.info(
    string.format(
      '[ProjectDiffView:jump_to_file] cursor_lnum=%d, mapped_lnum=%s, file=%s',
      lnum,
      file_info and file_info.lnum or 'nil',
      file_info and file_info.filename or 'nil'
    )
  )

  if not file_info or not file_info.filename then return end

  local filename = file_info.filename
  local source = self._sources[filename]
  if source then filename = fs.absolute_path(source.repo:get_path(), source.filename) end
  local target_lnum = file_info.lnum or 1

  self:destroy()
  event.await()

  navigation.open_file(filename, target_lnum)

  console.debug.info(string.format('[ProjectDiffView:jump_to_file] opened file=%s, set lnum=%d', filename, target_lnum))
end

function ProjectDiffView:show_blame_view()
  local component = self:get_navigatable_component()
  if not component or not component:is_valid() then return end

  local lnum = component:get_lnum()
  local file_info = self._line_to_file_map[lnum]
  if not file_info or not file_info.filename then return end

  local source = self._sources[file_info.filename] or { repo = self._repo, filename = file_info.filename }
  display_service.show_blame_view_for_file(source.filename, source.repo)
end

function ProjectDiffView:setup_keymaps()
  local project_diff_view_keymaps = project_diff_view_setting:get('keymaps')

  self:_setup_quit_keymap()

  local jump_key = keymap.get_key(project_diff_view_keymaps.jump)
  if jump_key then
    local jump_fn = self:_make_debounced(function()
      self:jump_to_file()
    end)
    self:_set_keymap_all_components('n', jump_key, jump_fn)
  end

  local toggle_key = keymap.get_key(project_diff_view_keymaps.toggle_diff_preference)
  if toggle_key then
    self:_set_keymap_all_components('n', toggle_key, function()
      local current = scene_setting:get('diff_preference')
      scene_setting:set('diff_preference', current == 'unified' and 'split' or 'unified')
    end)
  end

  self:_setup_hunk_navigation_keymaps()

  local blame_key = not (self._data and self._data.is_content) and keymap.get_key(project_diff_view_keymaps.blame)
  if blame_key then
    local blame_fn = self:_make_debounced(function()
      self:show_blame_view()
    end)
    self:_set_keymap_all_components('n', blame_key, blame_fn)
  end

  local double_click_fn = self:_make_debounced(function()
    self:jump_to_file()
  end)
  for _, component in ipairs(self:_get_all_diff_components()) do
    if component and component:is_valid() then component:on_click({ [2] = double_click_fn }) end
  end

  self:_setup_custom_keymaps(self._data and self._data.keymaps)
end

function ProjectDiffView:_mount_unified_view()
  self._update_gen = self._update_gen + 1

  self._patch_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = true,
  })

  event.await()
  self:_render(LayoutSpec.screen({
    LayoutSpec.view(self._patch_component, { flex = 1 }),
  }))

  self:setup_keymaps()

  if self._patch_component and self._patch_component:is_valid() then self._patch_component:focus() end
end

function ProjectDiffView:_mount_split_view()
  self._update_gen = self._update_gen + 1

  self._previous_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = false,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  self._current_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = true,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  event.await()
  self:_render(LayoutSpec.screen({
    LayoutSpec.horizontal({
      LayoutSpec.view(self._previous_component, { flex = 1 }),
      LayoutSpec.view(self._current_component, { flex = 1 }),
    }),
  }))

  self:setup_keymaps()

  if self._current_component and self._current_component:is_valid() then self._current_component:focus() end
end

function ProjectDiffView:_map_component()
  return self._layout_type == self.LAYOUT_SPLIT and self._current_component or self._patch_component
end

function ProjectDiffView:_refresh_diff(diff_file_entries)
  self._diff_file_entries = diff_file_entries
  self:_set_hunk_entries(diff_file_entries)

  local map_component = self:_map_component()
  if map_component then self._line_to_file_map = self:_build_line_to_file_map(map_component) end
end

function ProjectDiffView:_append_diff(diff_file_entries)
  local map_component = self:_map_component()
  local from_lnum = map_component and #map_component:get_all_line_metadata() + 1

  vim.list_extend(self._diff_file_entries, diff_file_entries)
  self:_append_hunk_entries(diff_file_entries)

  if map_component then self:_build_line_to_file_map(map_component, from_lnum, self._line_to_file_map) end
end

function ProjectDiffView:_create_view(data)
  local layout_type = data.layout_type or scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  self._layout_type = layout_type

  local repo

  if not data.is_content then
    self._repo = data.repo
    local err
    repo, err = self:_get_repo()
    if err then
      console.error('Failed to get repository: ' .. tostring(err))
      return false
    end

    self._repo = repo
  end

  if layout_type == self.LAYOUT_SPLIT then
    self:_mount_split_view()
  else
    self:_mount_unified_view()
  end

  self._loading_indicator:start(self:_get_all_diff_components())

  self._is_multi_repo = data.groups ~= nil
  local queue = { index = 1, stream = data.stream }
  vim.list_extend(queue, data.groups or { { repo = repo, entries = data.entries } })

  local diff_file_entries = {}
  repeat
    vim.list_extend(diff_file_entries, self:_next_entries(queue, self.FIRST_BATCH_SIZE))
  until #diff_file_entries > 0 or not self:_has_next(queue)

  self._loading_indicator:stop()

  if #diff_file_entries == 0 then
    event.await()
    console.info('No changes to display')
    self:destroy()
    return false
  end

  self:_refresh_diff(diff_file_entries)
  if self:_has_next(queue) then self:_load_remaining(queue) end

  return true
end

function ProjectDiffView:destroy()
  if self:is_destroyed() then return end

  self._loading_indicator:stop()
  self._update_gen = self._update_gen + 1

  View.destroy(self)
end

return ProjectDiffView
