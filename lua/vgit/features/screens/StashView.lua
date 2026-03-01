local lazy = require('vgit.core.lazy')

local Layout = lazy('vgit.ui.Layout')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')
local scene_setting = lazy('vgit.settings.scene')
local hunks_setting = lazy('vgit.settings.hunks')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local stash_view_setting = lazy('vgit.settings.stash_view')
local TreeComponent = lazy('vgit.ui.components.TreeComponent')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local PatchPreviewComponent = lazy('vgit.ui.components.PatchPreviewComponent')

local StashView = Object:extend()

StashView.DEBOUNCE_MS = 200
StashView.TREE_HEIGHT = 8
StashView.TREE_WIDTH = 50
StashView.LAYOUT_SPLIT = 'split'
StashView.LAYOUT_UNIFIED = 'unified'

function StashView:constructor()
  return {
    _data = nil,
    _repo = nil,
    _layout_type = nil,
    _tree_component = nil,
    _patch_component = nil,
    _previous_component = nil,
    _current_component = nil,
    _component_manager = nil,
    _debounce_cleanups = {},
    _current_commit = nil,
    _patch_cache = {},
    _update_gen = 0,
    _destroyed = false,
  }
end

function StashView:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
  return nil
end

function StashView:_get_active_component()
  if self._layout_type == self.LAYOUT_SPLIT then return self._current_component end
  return self._patch_component
end

function StashView:_set_keymap_on_component(component, mode, key, handler)
  if component and component:is_valid() then component:set_keymap({ mode = mode, key = key }, handler) end
end

function StashView:_set_keymap_all_diff_components(mode, key, handler)
  if self._layout_type == self.LAYOUT_SPLIT then
    self:_set_keymap_on_component(self._previous_component, mode, key, handler)
    self:_set_keymap_on_component(self._current_component, mode, key, handler)
  else
    self:_set_keymap_on_component(self._patch_component, mode, key, handler)
  end
end

function StashView:_build_stash_groups(stashes)
  local items = {}
  for _, commit in ipairs(stashes) do
    local revision = commit.context and commit.context.revision or '?'
    local message = commit.message or ''
    items[#items + 1] = {
      value = revision .. ': ' .. message,
      entry = { type = 'stash', commit = commit },
    }
  end
  return {
    {
      open = true,
      value = 'Stashes',
      metadata = {},
      items = items,
    },
  }
end

function StashView:_build_hunk_entries_for_commit(commit)
  local repo = self._repo
  if not repo then return {} end

  local revision = commit.context and commit.context.revision
  if not revision then return {} end

  local hunk_entries, err = repo:diff({ type = 'range', from = revision .. '^', to = revision })

  if err then
    console.debug.error(string.format('[StashView] git diff failed for %s: %s', revision, err[1] or tostring(err)))
    return {}
  end

  return hunk_entries or {}
end

function StashView:_split_hunk_entry(hunk, entry)
  local previous_diff = {}
  local current_diff = {}

  for _, line in ipairs(hunk.diff or {}) do
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

  local base = {
    filetype = entry.filetype,
    filename = entry.filename,
    original_lines = entry.original_lines,
    current_lines = entry.current_lines,
  }

  return vim.tbl_extend('force', base, {
    type = 'hunk',
    hunk = {
      header = hunk.header,
      diff = previous_diff,
      top = hunk.top,
      bot = hunk.bot,
    },
  }),
    vim.tbl_extend('force', base, {
      type = 'hunk',
      hunk = {
        header = hunk.header,
        diff = current_diff,
        top = hunk.top,
        bot = hunk.bot,
      },
    })
end

function StashView:_build_split_hunk_entries(hunk_entries)
  local previous_entries = {}
  local current_entries = {}

  for _, entry in ipairs(hunk_entries) do
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

function StashView:_set_hunk_entries(hunk_entries)
  if self._layout_type == self.LAYOUT_SPLIT then
    local previous_entries, current_entries = self:_build_split_hunk_entries(hunk_entries)
    if self._previous_component and self._previous_component:is_valid() then
      self._previous_component:set_props({ hunk_entries = previous_entries })
    end
    if self._current_component and self._current_component:is_valid() then
      self._current_component:set_props({ hunk_entries = current_entries })
    end
  else
    if self._patch_component and self._patch_component:is_valid() then
      self._patch_component:set_props({ hunk_entries = hunk_entries })
    end
  end
end

function StashView:_enrich_with_syntax(commit, initial_entries, gen)
  if self._destroyed or self._update_gen ~= gen then return end

  local repo = self._repo
  if not repo then return end

  local revision = commit.context and commit.context.revision
  if not revision then return end

  local file_specs = {}
  local seen = {}
  for _, entry in ipairs(initial_entries) do
    if entry.type == 'file_header' and entry.filetype and entry.filetype ~= 'text' and not seen[entry.filename] then
      seen[entry.filename] = true
      local old_name = entry.filename:match('^(.+) %-> .+$') or entry.filename
      local new_name = entry.filename:match('^.+ %-> (.+)$') or entry.filename
      file_specs[#file_specs + 1] = { display = entry.filename, old_name = old_name, new_name = new_name }
    end
  end

  if #file_specs == 0 then return end

  local parent_ref = revision .. '^'

  local funcs = {}
  for _, spec in ipairs(file_specs) do
    local old_name = spec.old_name
    local new_name = spec.new_name
    local display = spec.display
    funcs[#funcs + 1] = function()
      if self._update_gen ~= gen then return nil end
      local original_lines = repo:file_lines(old_name, parent_ref) or {}
      if self._update_gen ~= gen then return nil end
      local current_lines = repo:file_lines(new_name, revision) or {}
      return { display = display, original_lines = original_lines, current_lines = current_lines }
    end
  end

  local results = event.all(funcs)
  if self._destroyed or self._update_gen ~= gen then return end

  local content_map = {}
  for _, r in ipairs(results) do
    if r then content_map[r.display] = { original_lines = r.original_lines, current_lines = r.current_lines } end
  end

  local enriched = {}
  for _, entry in ipairs(initial_entries) do
    if entry.type == 'file_header' then
      local content = content_map[entry.filename]
      if content then
        local new_entry = {}
        for k, v in pairs(entry) do
          new_entry[k] = v
        end
        new_entry.original_lines = content.original_lines
        new_entry.current_lines = content.current_lines
        enriched[#enriched + 1] = new_entry
      else
        enriched[#enriched + 1] = entry
      end
    else
      enriched[#enriched + 1] = entry
    end
  end

  if revision then self._patch_cache[revision] = enriched end

  if self._update_gen == gen then self:_set_hunk_entries(enriched) end
end

function StashView:_update_patch(commit)
  if not commit then return end
  self._current_commit = commit
  self._update_gen = self._update_gen + 1
  local gen = self._update_gen

  local revision = commit.context and commit.context.revision

  if revision and self._patch_cache[revision] then
    self:_set_hunk_entries(self._patch_cache[revision])
    return
  end

  local hunk_entries = self:_build_hunk_entries_for_commit(commit)

  if self._update_gen ~= gen then return end

  if revision then self._patch_cache[revision] = hunk_entries end

  self:_set_hunk_entries(hunk_entries)

  event.async(function()
    self:_enrich_with_syntax(commit, hunk_entries, gen)
  end)()
end

function StashView:_refresh_stash_list()
  local repo = self._repo
  if not repo then return end

  self._patch_cache = {}

  local stashes, err = repo:stash_list()

  if err then
    console.debug.error(string.format('[StashView] list failed: %s', err[1] or tostring(err)))
    return
  end

  if not stashes or #stashes == 0 then
    self:destroy()
    return
  end

  local groups = self:_build_stash_groups(stashes)

  if self._tree_component and self._tree_component:is_valid() then self._tree_component:set_list(groups) end
end

function StashView:_move_to_first_stash()
  if not self._tree_component then return end
  local _, lnum = self._tree_component:find_list_item(function(node)
    return node.entry ~= nil and node.entry.commit ~= nil
  end)
  if lnum then self._tree_component:set_lnum(lnum) end
end

function StashView:_get_current_commit()
  if self._tree_component and self._tree_component:is_valid() then
    local item = self._tree_component:get_selected_entry()
    if not item then return nil end
    local entry = item.entry or item
    if entry and entry.commit then return entry.commit end
  end
  return self._current_commit
end

function StashView:get_hunk_alignment()
  return stash_view_setting:get('hunk_alignment')
end

function StashView:get_hunk_alignment_offset()
  return stash_view_setting:get('hunk_alignment_offset') or 0
end

function StashView:_get_current_mark_index(component)
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

function StashView:hunk_down()
  local component = self:_get_active_component()
  if component and component:is_valid() then
    component:hunk_down(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk({ index = index, count = count }) end
  end
end

function StashView:hunk_up()
  local component = self:_get_active_component()
  if component and component:is_valid() then
    component:hunk_up(self:get_hunk_alignment(), self:get_hunk_alignment_offset())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk({ index = index, count = count }) end
  end
end

function StashView:setup_keymaps()
  local keymaps = stash_view_setting:get('keymaps')
  local scene_keymaps = scene_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      if self._tree_component and self._tree_component:is_valid() then
        self._tree_component:set_keymap('n', quit_key, function()
          self._component_manager:destroy()
        end, 'Quit')
      end
      self:_set_keymap_all_diff_components('n', quit_key, function()
        self._component_manager:destroy()
      end)
    end
  end

  local add_key = self:get_key(keymaps.add)
  if add_key then
    local add_fn, add_cleanup = event.debounce_async(function()
      local _, err = self._repo:stash_add()
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('Changes stashed')
      self:_refresh_stash_list()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, add_cleanup)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', add_key, add_fn, 'Stash current changes')
    end
    self:_set_keymap_all_diff_components('n', add_key, add_fn)
  end

  local apply_key = self:get_key(keymaps.apply)
  if apply_key then
    local apply_fn, apply_cleanup = event.debounce_async(function()
      local commit = self:_get_current_commit()
      if not commit then return end
      local revision = commit.context and commit.context.revision
      if not revision then return end
      local _, err = self._repo:stash_apply(revision)
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('Stash applied: ' .. revision)
      self:_refresh_stash_list()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, apply_cleanup)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', apply_key, apply_fn, 'Apply stash')
    end
    self:_set_keymap_all_diff_components('n', apply_key, apply_fn)
  end

  local pop_key = self:get_key(keymaps.pop)
  if pop_key then
    local pop_fn, pop_cleanup = event.debounce_async(function()
      local commit = self:_get_current_commit()
      if not commit then return end
      local revision = commit.context and commit.context.revision
      if not revision then return end
      local _, err = self._repo:stash_pop(revision)
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('Stash popped: ' .. revision)
      self:_refresh_stash_list()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, pop_cleanup)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', pop_key, pop_fn, 'Pop stash')
    end
    self:_set_keymap_all_diff_components('n', pop_key, pop_fn)
  end

  local drop_key = self:get_key(keymaps.drop)
  if drop_key then
    local drop_fn, drop_cleanup = event.debounce_async(function()
      local commit = self:_get_current_commit()
      if not commit then return end
      local revision = commit.context and commit.context.revision
      if not revision then return end
      local _, err = self._repo:stash_drop(revision)
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('Stash dropped: ' .. revision)
      self:_refresh_stash_list()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, drop_cleanup)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', drop_key, drop_fn, 'Drop stash')
    end
    self:_set_keymap_all_diff_components('n', drop_key, drop_fn)
  end

  local clear_key = self:get_key(keymaps.clear)
  if clear_key then
    local clear_fn, clear_cleanup = event.debounce_async(function()
      local _, err = self._repo:stash_clear()
      if err then
        console.error(err[1] or tostring(err))
        return
      end
      console.info('All stashes cleared')
      self:destroy()
    end, self.DEBOUNCE_MS)
    table.insert(self._debounce_cleanups, clear_cleanup)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', clear_key, clear_fn, 'Clear all stashes')
    end
    self:_set_keymap_all_diff_components('n', clear_key, clear_fn)
  end

  local hunks_keymaps = hunks_setting:get('keymaps')

  local down_key = self:get_key(hunks_keymaps.down)
  if down_key then
    local down_fn = event.async(function()
      self:hunk_down()
    end)
    self:_set_keymap_all_diff_components('n', down_key, down_fn)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', down_key, down_fn, 'Next hunk')
    end
  end

  local up_key = self:get_key(hunks_keymaps.up)
  if up_key then
    local up_fn = event.async(function()
      self:hunk_up()
    end)
    self:_set_keymap_all_diff_components('n', up_key, up_fn)
    if self._tree_component and self._tree_component:is_valid() then
      self._tree_component:set_keymap('n', up_key, up_fn, 'Previous hunk')
    end
  end
end

function StashView:_create_unified(groups)
  self._patch_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = false,
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.vertical({
      LayoutSpec.view(self._patch_component),
      LayoutSpec.view(self._tree_component),
    }),
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()
  if self._tree_component:is_valid() then self._tree_component:focus() end

  self:_move_to_first_stash()
  local first_commit = self:_get_current_commit()
  if first_commit then self:_update_patch(first_commit) end
end

function StashView:_create_split()
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
    focus = false,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.vertical({
      LayoutSpec.horizontal({
        LayoutSpec.view(self._previous_component, { flex = 1 }),
        LayoutSpec.view(self._current_component, { flex = 1 }),
      }),
      LayoutSpec.view(self._tree_component),
    }),
  })

  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()
  if self._tree_component:is_valid() then self._tree_component:focus() end

  self:_move_to_first_stash()
  local first_commit = self:_get_current_commit()
  if first_commit then self:_update_patch(first_commit) end
end

function StashView:create(data)
  if not data then
    console.error('[StashView] No data provided to create()')
    return false
  end

  if type(data) ~= 'table' then
    console.error('[StashView] Expected table, got ' .. type(data))
    return false
  end

  if not data.stashes or type(data.stashes) ~= 'table' or #data.stashes == 0 then
    console.error('[StashView] Invalid data: stashes must be a non-empty table')
    return false
  end

  self._data = data
  self._repo = data.repo
  self._layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  local groups = self:_build_stash_groups(data.stashes)

  local on_move_fn, on_move_cleanup = event.debounce_async(function(item)
    if not item then return end
    local entry = item.entry or item
    if entry and entry.commit then self:_update_patch(entry.commit) end
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, on_move_cleanup)

  self._tree_component = TreeComponent({
    list = groups,
    title = '',
    height = self.TREE_HEIGHT,
    focus = true,
  })

  self._tree_component:set_on_move(on_move_fn)

  if self._layout_type == self.LAYOUT_SPLIT then
    self:_create_split()
  else
    self:_create_unified(groups)
  end

  return true
end

function StashView:is_destroyed()
  return self._destroyed
end

function StashView:destroy()
  if self._destroyed then return end
  self._destroyed = true
  for _, cleanup in ipairs(self._debounce_cleanups) do
    cleanup()
  end
  self._debounce_cleanups = {}
  if self._component_manager then self._component_manager:destroy() end
end

return StashView
