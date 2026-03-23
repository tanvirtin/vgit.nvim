local lazy = require('vgit.core.lazy')

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
ProjectDiffView.LAYOUT_SPLIT = 'split'
ProjectDiffView.LAYOUT_UNIFIED = 'unified'

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

function ProjectDiffView:_classify_entries(data)
  local has_staged = false
  local has_unstaged = false
  local conflict_entries = {}

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if not file_entry.diff and file_entry.status then
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

function ProjectDiffView:_build_line_to_file_map(component)
  local line_to_file_map = {}
  local line_metadata = component:get_all_line_metadata()

  for lnum, meta in pairs(line_metadata) do
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

  -- Staged file diffs
  if staged_fn_idx then
    local file_diffs = fetch_results[staged_fn_idx]
    if file_diffs then
      for _, fd in ipairs(file_diffs) do
        all_entries[#all_entries + 1] = {
          type = 'diff_file',
          filename = fd.filename,
          filetype = fd.filetype,
          diff = fd.diff,
          original_lines = fd.original_lines,
          current_lines = fd.current_lines,
        }
      end
    end
  end

  -- Unstaged file diffs
  if unstaged_fn_idx then
    local file_diffs = fetch_results[unstaged_fn_idx]
    if file_diffs then
      for _, fd in ipairs(file_diffs) do
        all_entries[#all_entries + 1] = {
          type = 'diff_file',
          filename = fd.filename,
          filetype = fd.filetype,
          diff = fd.diff,
          original_lines = fd.original_lines,
          current_lines = fd.current_lines,
        }
      end
    end
  end

  -- Conflict diffs
  for i, entry in ipairs(conflict_entries) do
    local result = fetch_results[conflict_start_idx + i - 1]
    if result and result[1] then
      local diff = result[1]
      all_entries[#all_entries + 1] = {
        type = 'diff_file',
        filename = entry.status.filename,
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
      if file_entry.diff then
        local status = file_entry.status
        if status and status.filename then
          local display_filename = status.filename
          if status.old_filename then
            display_filename = status.old_filename .. ' -> ' .. status.filename
          end
          entries[#entries + 1] = {
            type = 'diff_file',
            filename = display_filename,
            filetype = status.filetype,
            diff = file_entry.diff,
            original_lines = file_entry.original_lines or {},
            current_lines = file_entry.current_lines or {},
          }
        end
      end
    end
  end

  return entries
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

  display_service.show_blame_view_for_file(file_info.filename)
end

function ProjectDiffView:setup_keymaps()
  local project_diff_view_keymaps = project_diff_view_setting:get('keymaps')

  self:_setup_quit_keymap()

  local jump_key = keymap.get_key(project_diff_view_keymaps.jump)
  if jump_key then
    local jump_fn = self:_make_debounced(function() self:jump_to_file() end)
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

  local blame_fn = self:_make_debounced(function() self:show_blame_view() end)
  self:_set_keymap_all_components('n', 'b', blame_fn)
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

function ProjectDiffView:_refresh_diff(diff_file_entries)
  self._diff_file_entries = diff_file_entries
  self:_set_hunk_entries(diff_file_entries)

  local map_component = self._layout_type == self.LAYOUT_SPLIT and self._current_component or self._patch_component
  if map_component then self._line_to_file_map = self:_build_line_to_file_map(map_component) end
end

function ProjectDiffView:_create_view(data)
  local layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  self._layout_type = layout_type

  local repo, err = repository.current()
  if err then
    console.error('Failed to get repository: ' .. tostring(err))
    return false
  end

  self._repo = repo

  if layout_type == self.LAYOUT_SPLIT then
    self:_mount_split_view()
  else
    self:_mount_unified_view()
  end

  self._loading_indicator:start(self:_get_all_diff_components())

  local diff_file_entries = self:_build_diff_file_entries(repo, data)

  self._loading_indicator:stop()

  if #diff_file_entries == 0 then
    event.await()
    console.info('No changes to display')
    self:destroy()
    return false
  end

  self:_refresh_diff(diff_file_entries)

  return true
end

function ProjectDiffView:destroy()
  if self:is_destroyed() then return end

  self._loading_indicator:stop()
  self._update_gen = self._update_gen + 1

  View.destroy(self)
end

return ProjectDiffView
