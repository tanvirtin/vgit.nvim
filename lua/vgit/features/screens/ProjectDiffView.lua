local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local utils = lazy('vgit.core.utils')
local Layout = lazy('vgit.ui.Layout')
local event = lazy('vgit.core.event')
local Window = lazy('vgit.core.Window')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')
local git_diff = lazy('vgit.git.git_diff')
local git_show = lazy('vgit.git.git_show')
local git_blame = lazy('vgit.git.git_blame')
local repository = lazy('vgit.git.repository')
local scene_setting = lazy('vgit.settings.scene')
local hunks_setting = lazy('vgit.settings.hunks')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local display_service = lazy('vgit.ui.display_service')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local project_diff_view_setting = lazy('vgit.settings.project_diff_view')
local PatchPreviewComponent = lazy('vgit.ui.components.PatchPreviewComponent')

local ProjectDiffView = Object:extend()

ProjectDiffView.DEBOUNCE_MS = 100
ProjectDiffView.LAYOUT_SPLIT = 'split'
ProjectDiffView.LAYOUT_UNIFIED = 'unified'
ProjectDiffView.CONFLICT_CURRENT_ONLY = {
  conflict_current_mark = true,
  conflict_current = true,
}
ProjectDiffView.CONFLICT_PREVIOUS_ONLY = {
  conflict_incoming = true,
  conflict_incoming_mark = true,
}

function ProjectDiffView:constructor()
  return {
    _data = nil,
    _repo = nil,
    _layout_type = nil,
    _patch_component = nil,
    _previous_component = nil,
    _current_component = nil,
    _component_manager = nil,
    _patch_entries = {},
    _line_to_file_map = {},
    _debounce_cleanups = {},
    _destroyed = false,
    _update_gen = 0,
  }
end

function ProjectDiffView:_handle_git_error(err, operation_name)
  if err then
    console.debug.error(string.format('[ProjectDiffView] %s failed: %s', operation_name, err))
    return false
  end
  return true
end

function ProjectDiffView:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
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

function ProjectDiffView:_get_file_lines(repo, filename, ref)
  if ref == 'disk' then return fs.read_file(fs.absolute_path(repo:get_path(), filename)) or {} end
  return repo:file_lines(filename, ref) or {}
end

function ProjectDiffView:_get_diff_for_entry(repo, entry)
  local status = entry.status
  local filename = status.filename

  local diff_spec = { type = 'conflict', filename = filename }

  local diff_data, err = repo:diff(diff_spec, {})
  if err then
    console.error(string.format('[ProjectDiffView] diff for %s failed: %s', filename, err))
    return nil
  end

  if not diff_data then
    console.error(string.format('[ProjectDiffView] diff for %s returned nil', filename))
    return nil
  end

  return diff_data
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

function ProjectDiffView:_conflict_diff_to_patch_entries(diff_data, status)
  local patch_entries = {}
  local marks = diff_data.marks
  local file_lines = diff_data.lines

  if not marks or #marks == 0 or not file_lines then return patch_entries end

  local lnum_to_type = {}
  for _, lc in ipairs(diff_data.lnum_changes or {}) do
    lnum_to_type[lc.lnum] = lc.type
  end

  patch_entries[#patch_entries + 1] = {
    type = 'file_header',
    filename = status.filename,
    filetype = status.filetype,
  }

  for _, mark in ipairs(marks) do
    local top = mark.top or 1
    local bot = mark.bot or top
    local count = bot - top + 1

    local diff_lines = {}
    local lnum_changes = {}
    for idx = 1, count do
      local lnum = top + idx - 1
      diff_lines[idx] = ' ' .. (file_lines[lnum] or '')
      local t = lnum_to_type[lnum]
      if t then lnum_changes[idx] = { type = t } end
    end

    patch_entries[#patch_entries + 1] = {
      type = 'hunk',
      hunk = {
        header = string.format('@@ -%d,%d +%d,%d @@ conflict', top, count, top, count),
        diff = diff_lines,
        lnum_changes = lnum_changes,
        top = top,
        bot = bot,
      },
      filetype = status.filetype,
      filename = status.filename,
    }
  end

  return patch_entries
end

function ProjectDiffView:_precomputed_entry_to_patch_entries(file_entry)
  local patch_entries = {}
  local status = file_entry.status
  if not status then return patch_entries end

  local diff_data = file_entry.diff
  if not diff_data.hunks or #diff_data.hunks == 0 then
    console.debug.error(string.format('[ProjectDiffView] no hunks for %s', status.filename))
    return patch_entries
  end

  local display_filename = status.filename
  if status.old_filename then display_filename = status.old_filename .. ' -> ' .. status.filename end

  patch_entries[#patch_entries + 1] = {
    type = 'file_header',
    filename = display_filename,
    filetype = status.filetype,
    original_lines = file_entry.original_lines,
    current_lines = file_entry.current_lines,
  }

  for _, hunk in ipairs(diff_data.hunks) do
    patch_entries[#patch_entries + 1] = {
      type = 'hunk',
      hunk = hunk,
      filetype = status.filetype,
      filename = status.filename,
    }
  end

  return patch_entries
end

function ProjectDiffView:_build_line_to_file_map(patch_entries)
  local line_to_file_map = {}
  local current_line = 1
  local current_real_filename = nil

  for _, entry in ipairs(patch_entries) do
    if entry.type == 'file_header' then
      current_real_filename = entry.filename:match('^.+ %-> (.+)$') or entry.filename
      line_to_file_map[current_line] = { filename = current_real_filename, lnum = 1 }
      current_line = current_line + 1
      line_to_file_map[current_line] = { filename = current_real_filename, lnum = 1 }
      current_line = current_line + 1
      line_to_file_map[current_line] = { filename = current_real_filename, lnum = 1 }
      current_line = current_line + 1
    elseif entry.type == 'hunk' then
      local hunk = entry.hunk
      local filename = entry.filename or current_real_filename

      if hunk.header then
        line_to_file_map[current_line] = { filename = filename, lnum = hunk.top or 1 }
        current_line = current_line + 1
      end

      local diff_line_offset = 0
      for _, line in ipairs(hunk.diff or {}) do
        line_to_file_map[current_line] = { filename = filename, lnum = (hunk.top or 1) + diff_line_offset }
        current_line = current_line + 1
        if line:sub(1, 1) ~= '-' then diff_line_offset = diff_line_offset + 1 end
      end

      line_to_file_map[current_line] = { filename = filename, lnum = hunk.top or 1 }
      current_line = current_line + 1
    end
  end

  return line_to_file_map
end

function ProjectDiffView:_build_patch_entries(repo, data)
  local repo_path = repo.get_path and repo:get_path() or nil
  local has_staged, has_unstaged, conflict_entries = self:_classify_entries(data)

  local fetch_funcs = {}
  local staged_fn_idx = nil
  local unstaged_fn_idx = nil

  if has_staged and repo_path then
    staged_fn_idx = #fetch_funcs + 1
    fetch_funcs[#fetch_funcs + 1] = function() return git_diff.staged_patch_entries(repo_path) end
  end

  if has_unstaged and repo_path then
    unstaged_fn_idx = #fetch_funcs + 1
    fetch_funcs[#fetch_funcs + 1] = function() return git_diff.unstaged_patch_entries(repo_path) end
  end

  local conflict_start_idx = #fetch_funcs + 1
  for _, entry in ipairs(conflict_entries) do
    local e = entry
    fetch_funcs[#fetch_funcs + 1] = function() return { self:_get_diff_for_entry(repo, e) } end
  end

  local fetch_results = {}
  if #fetch_funcs > 0 then fetch_results = event.all(fetch_funcs) end

  local all_patch_entries = {}

  if staged_fn_idx then
    local staged = fetch_results[staged_fn_idx]
    if staged then
      for _, e in ipairs(staged) do all_patch_entries[#all_patch_entries + 1] = e end
    end
  end

  if unstaged_fn_idx then
    local unstaged = fetch_results[unstaged_fn_idx]
    if unstaged then
      for _, e in ipairs(unstaged) do all_patch_entries[#all_patch_entries + 1] = e end
    end
  end

  for i, entry in ipairs(conflict_entries) do
    local result = fetch_results[conflict_start_idx + i - 1]
    if result and result[1] then
      local entries = self:_conflict_diff_to_patch_entries(result[1], entry.status)
      for _, e in ipairs(entries) do all_patch_entries[#all_patch_entries + 1] = e end
    end
  end

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if file_entry.diff then
        local entries = self:_precomputed_entry_to_patch_entries(file_entry)
        for _, e in ipairs(entries) do all_patch_entries[#all_patch_entries + 1] = e end
      end
    end
  end

  console.debug.info(string.format('[ProjectDiffView] built %d patch entries', #all_patch_entries))
  return all_patch_entries, self:_build_line_to_file_map(all_patch_entries)
end

function ProjectDiffView:_get_active_component()
  if self._layout_type == self.LAYOUT_SPLIT then return self._current_component end
  return self._patch_component
end

function ProjectDiffView:get_hunk_alignment()
  return project_diff_view_setting:get('hunk_alignment')
end

function ProjectDiffView:_get_current_mark_index(component)
  local marks = component:get_marks()
  if #marks == 0 then return nil, 0 end

  local lnum = component:get_lnum()

  for i, mark in ipairs(marks) do
    if lnum >= mark.top and lnum <= mark.bot then
      return i, #marks
    elseif mark.top > lnum then
      return math.max(1, i - 1), #marks
    end
  end

  return #marks, #marks
end

function ProjectDiffView:hunk_up()
  local component = self:_get_active_component()
  if component and component:is_valid() then
    component:hunk_up(self:get_hunk_alignment())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk(index, count) end
  end
end

function ProjectDiffView:hunk_down()
  local component = self:_get_active_component()
  if component and component:is_valid() then
    component:hunk_down(self:get_hunk_alignment())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk(index, count) end
  end
end

function ProjectDiffView:jump_to_file()
  local component = self:_get_active_component()
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

  fs.open(filename)

  local window = Window(0)
  window:set_lnum(target_lnum)

  console.debug.info(string.format('[ProjectDiffView:jump_to_file] opened file=%s, set lnum=%d', filename, target_lnum))
end

function ProjectDiffView:show_blame_view()
  local component = self:_get_active_component()
  if not component or not component:is_valid() then return end

  local lnum = component:get_lnum()
  local file_info = self._line_to_file_map[lnum]
  if not file_info or not file_info.filename then return end

  local filename = file_info.filename

  local repo, err = repository.current()
  if not self:_handle_git_error(err, 'repository.current') then return end

  local repo_path = repo:get_path()
  local filetype = fs.detect_filetype(filename)

  local blames, blame_err = git_blame.list(repo_path, filename)
  if blame_err or not blames or #blames == 0 then
    console.info('No blame information available for this file')
    return
  end

  local lines, lines_err = git_show.lines(repo_path, filename, 'HEAD')
  if lines_err or not lines then lines = {} end

  display_service.show_blame_view({
    filename = filename,
    filetype = filetype,
    reponame = repo_path,
    blames = blames,
    lines = lines,
  })
end

function ProjectDiffView:_set_keymap_on_component(component, mode, key, handler)
  if component and component:is_valid() then component:set_keymap({
    mode = mode,
    key = key,
  }, handler) end
end

function ProjectDiffView:_set_keymap_all_components(mode, key, handler)
  if self._layout_type == self.LAYOUT_SPLIT then
    self:_set_keymap_on_component(self._previous_component, mode, key, handler)
    self:_set_keymap_on_component(self._current_component, mode, key, handler)
  else
    self:_set_keymap_on_component(self._patch_component, mode, key, handler)
  end
end

function ProjectDiffView:setup_keymaps()
  local scene_keymaps = scene_setting:get('keymaps')
  local project_diff_view_keymaps = project_diff_view_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      self:_set_keymap_all_components('n', quit_key, function()
        self._component_manager:destroy()
      end)
    end
  end

  local jump_key = self:get_key(project_diff_view_keymaps.jump)
  if jump_key then
    local jump_fn, jump_cleanup = event.debounce_async(function()
      self:jump_to_file()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, jump_cleanup)

    self:_set_keymap_all_components('n', jump_key, jump_fn)
  end

  local toggle_key = self:get_key(project_diff_view_keymaps.toggle_diff_preference)
  if toggle_key then
    self:_set_keymap_all_components('n', toggle_key, function()
      display_service.toggle_diff_preference()
    end)
  end

  local down_key = self:get_key(hunks_keymaps.down)
  if down_key then
    local down_fn = event.async(function()
      self:hunk_down()
    end)
    self:_set_keymap_all_components('n', down_key, down_fn)
  end

  local up_key = self:get_key(hunks_keymaps.up)
  if up_key then
    local up_fn = event.async(function()
      self:hunk_up()
    end)
    self:_set_keymap_all_components('n', up_key, up_fn)
  end

  local blame_fn, blame_cleanup = event.debounce_async(function()
    self:show_blame_view()
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, blame_cleanup)
  self:_set_keymap_all_components('n', 'b', blame_fn)
end

function ProjectDiffView:_split_hunk_entry(hunk, entry)
  local previous_diff = {}
  local current_diff = {}
  local previous_lnum_changes = hunk.lnum_changes and {} or nil
  local current_lnum_changes = hunk.lnum_changes and {} or nil

  for i, line in ipairs(hunk.diff or {}) do
    local lc = hunk.lnum_changes and hunk.lnum_changes[i]
    local t = lc and lc.type

    if t and self.CONFLICT_CURRENT_ONLY[t] then
      previous_diff[#previous_diff + 1] = ' '
      current_diff[#current_diff + 1] = line
      if previous_lnum_changes then previous_lnum_changes[i] = { type = 'void' } end
      if current_lnum_changes then current_lnum_changes[i] = lc end
    elseif t and self.CONFLICT_PREVIOUS_ONLY[t] then
      previous_diff[#previous_diff + 1] = line
      current_diff[#current_diff + 1] = ' '
      if previous_lnum_changes then previous_lnum_changes[i] = lc end
      if current_lnum_changes then current_lnum_changes[i] = { type = 'void' } end
    elseif t then
      previous_diff[#previous_diff + 1] = line
      current_diff[#current_diff + 1] = line
      if previous_lnum_changes then previous_lnum_changes[i] = lc end
      if current_lnum_changes then current_lnum_changes[i] = lc end
    else
      local prefix = line:sub(1, 1)
      if prefix == '-' then
        previous_diff[#previous_diff + 1] = line
        current_diff[#current_diff + 1] = ' '
      elseif prefix == '+' then
        previous_diff[#previous_diff + 1] = ' '
        current_diff[#current_diff + 1] = line
      else
        previous_diff[#previous_diff + 1] = line
        current_diff[#current_diff + 1] = line
      end
    end
  end

  local base = {
    filetype = entry.filetype,
    filename = entry.filename,
    original_lines = entry.original_lines,
    current_lines = entry.current_lines,
  }

  return
    vim.tbl_extend('force', base, { type = 'hunk', hunk = {
      header = hunk.header, diff = previous_diff,
      lnum_changes = previous_lnum_changes, top = hunk.top, bot = hunk.bot,
    } }),
    vim.tbl_extend('force', base, { type = 'hunk', hunk = {
      header = hunk.header, diff = current_diff,
      lnum_changes = current_lnum_changes, top = hunk.top, bot = hunk.bot,
    } })
end

function ProjectDiffView:_build_split_patch_entries(patch_entries)
  local previous_entries = {}
  local current_entries = {}

  for _, entry in ipairs(patch_entries) do
    if entry.type == 'file_header' then
      previous_entries[#previous_entries + 1] = vim.tbl_extend('force', {}, entry)
      current_entries[#current_entries + 1] = vim.tbl_extend('force', {}, entry)
    elseif entry.type == 'hunk' then
      local previous_entry, current_entry = self:_split_hunk_entry(entry.hunk, entry)
      previous_entries[#previous_entries + 1] = previous_entry
      current_entries[#current_entries + 1] = current_entry
    end
  end

  return previous_entries, current_entries
end

function ProjectDiffView:_collect_file_specs(patch_entries, data)
  local file_type_map = {}
  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      if file_entry.status and not file_entry.diff then
        file_type_map[file_entry.status.filename] = file_entry.type
      end
    end
  end

  local file_specs = {}
  local seen = {}
  for _, entry in ipairs(patch_entries) do
    if entry.type == 'file_header'
        and entry.filetype and entry.filetype ~= 'text'
        and not entry.original_lines
        and not seen[entry.filename] then
      local new_name = entry.filename:match('^.+ %-> (.+)$') or entry.filename
      local old_name = entry.filename:match('^(.+) %-> .+$') or entry.filename
      local file_type = file_type_map[new_name] or 'unstaged'
      if file_type ~= 'unmerged' then
        seen[entry.filename] = true
        local from, to
        if file_type == 'staged' then
          from, to = 'HEAD', 'index'
        else
          from, to = 'index', 'disk'
        end
        file_specs[#file_specs + 1] = {
          display = entry.filename,
          old_name = old_name,
          new_name = new_name,
          from = from,
          to = to,
        }
      end
    end
  end

  return file_specs
end

function ProjectDiffView:_apply_syntax_to_patch_entries(patch_entries, content_map)
  local enriched = {}
  for _, entry in ipairs(patch_entries) do
    if entry.type == 'file_header' then
      local content = content_map[entry.filename]
      if content then
        enriched[#enriched + 1] = vim.tbl_extend('force', entry, {
          original_lines = content.original_lines,
          current_lines = content.current_lines,
        })
      else
        enriched[#enriched + 1] = entry
      end
    else
      enriched[#enriched + 1] = entry
    end
  end
  return enriched
end

function ProjectDiffView:_enrich_with_syntax(patch_entries, data, gen)
  if self._destroyed or self._update_gen ~= gen then return end

  local repo = self._repo
  if not repo then return end

  local file_specs = self:_collect_file_specs(patch_entries, data)
  if #file_specs == 0 then return end

  local funcs = {}
  for _, spec in ipairs(file_specs) do
    local old_name, new_name, from, to, display = spec.old_name, spec.new_name, spec.from, spec.to, spec.display
    funcs[#funcs + 1] = function()
      if self._update_gen ~= gen then return nil end
      local original_lines = self:_get_file_lines(repo, old_name, from)
      if self._update_gen ~= gen then return nil end
      local current_lines = self:_get_file_lines(repo, new_name, to)
      return { display = display, original_lines = original_lines, current_lines = current_lines }
    end
  end

  local results = event.all(funcs)
  if self._destroyed or self._update_gen ~= gen then return end

  local content_map = {}
  for _, r in ipairs(results) do
    if r then content_map[r.display] = { original_lines = r.original_lines, current_lines = r.current_lines } end
  end

  local enriched = self:_apply_syntax_to_patch_entries(patch_entries, content_map)
  if self._update_gen ~= gen then return end

  self._patch_entries = enriched

  if self._layout_type == self.LAYOUT_SPLIT then
    local previous_entries, current_entries = self:_build_split_patch_entries(enriched)
    if self._previous_component and self._previous_component:is_valid() then
      self._previous_component:set_props({ patch_entries = previous_entries })
    end
    if self._current_component and self._current_component:is_valid() then
      self._current_component:set_props({ patch_entries = current_entries })
    end
  else
    if self._patch_component and self._patch_component:is_valid() then
      self._patch_component:set_props({ patch_entries = enriched })
    end
  end
end

function ProjectDiffView:_create_unified_view(patch_entries, line_to_file_map, data)
  self._patch_entries = patch_entries
  self._line_to_file_map = line_to_file_map

  self._update_gen = self._update_gen + 1
  local gen = self._update_gen

  self._patch_component = PatchPreviewComponent({
    patch_entries = patch_entries,
    focus = true,
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(self._patch_component, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()

  if self._patch_component and self._patch_component:is_valid() then self._patch_component:focus() end

  self:_enrich_with_syntax(patch_entries, data, gen)

  return true
end

function ProjectDiffView:_create_split_view(patch_entries, line_to_file_map, data)
  self._patch_entries = patch_entries
  self._line_to_file_map = line_to_file_map

  self._update_gen = self._update_gen + 1
  local gen = self._update_gen

  local previous_entries, current_entries = self:_build_split_patch_entries(patch_entries)

  self._previous_component = PatchPreviewComponent({
    patch_entries = previous_entries,
    focus = false,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  self._current_component = PatchPreviewComponent({
    patch_entries = current_entries,
    focus = true,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.horizontal({
      LayoutSpec.view(self._previous_component, { flex = 1 }),
      LayoutSpec.view(self._current_component, { flex = 1 }),
    }),
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()

  if self._current_component and self._current_component:is_valid() then self._current_component:focus() end

  self:_enrich_with_syntax(patch_entries, data, gen)

  return true
end

function ProjectDiffView:_create_view(data)
  local layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  self._layout_type = layout_type

  local repo, err = repository.current()
  if err then
    console.debug.error(string.format('[ProjectDiffView] repository.current() failed: %s', err))
    return false
  end

  self._repo = repo

  local patch_entries, line_to_file_map = self:_build_patch_entries(repo, data)

  if #patch_entries == 0 then
    event.await()
    console.info('No changes to display')
    return false
  end

  if layout_type == self.LAYOUT_SPLIT then
    return self:_create_split_view(patch_entries, line_to_file_map, data)
  end
  return self:_create_unified_view(patch_entries, line_to_file_map, data)
end

function ProjectDiffView:emit_cleanup_events()
  if self._patch_component then self._patch_component:component_will_unmount() end
  if self._previous_component then self._previous_component:component_will_unmount() end
  if self._current_component then self._current_component:component_will_unmount() end
end

function ProjectDiffView:destroy()
  if self._destroyed then return end
  self._destroyed = true
  self._update_gen = self._update_gen + 1
  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}
  self:emit_cleanup_events()
  if self._component_manager then self._component_manager:destroy() end
end

return ProjectDiffView
