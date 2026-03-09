local lazy = require('vgit.core.lazy')

local Layout = lazy('vgit.ui.Layout')
local event = lazy('vgit.core.event')
local Object = lazy('vgit.core.Object')
local console = lazy('vgit.core.console')
local git_stash = lazy('vgit.git.git_stash')
local scene_setting = lazy('vgit.settings.scene')
local hunks_setting = lazy('vgit.settings.hunks')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local statusline = lazy('vgit.core.statusline_state')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local stash_view_setting = lazy('vgit.settings.stash_view')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')
local PatchPreviewComponent = lazy('vgit.ui.components.PatchPreviewComponent')

local StashView = Object:extend()

StashView.DEBOUNCE_MS = 200
StashView.SEARCH_HEIGHT = 10
StashView.LAYOUT_SPLIT = 'split'
StashView.LAYOUT_UNIFIED = 'unified'

function StashView:constructor()
  return {
    _data = nil,
    _repo = nil,
    _layout_type = nil,
    _search_component = nil,
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
  if type(keymap) == 'string' then return keymap end
  if type(keymap) == 'table' then return keymap.key end
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

function StashView:_format_stash_index(revision)
  local index = revision:match('stash@{(%d+)}')
  if index then return '{' .. index .. '}' end
  return revision
end

function StashView:_parse_stash_message(message)
  local branch, rest = message:match('^WIP on ([^:]+):%s*(.*)')
  if branch and rest then
    local msg = rest:match('^%x+%s+(.*)') or rest
    return branch, msg
  end

  branch, rest = message:match('^On ([^:]+):%s*(.*)')
  if branch then return branch, rest end

  return nil, message
end

function StashView:_build_items(stashes)
  local items = {}
  for _, commit in ipairs(stashes) do
    local index = self:_format_stash_index(commit.context and commit.context.revision or '?')
    local age = commit:age()
    local age_display = age and age.display or ''
    local branch, message = self:_parse_stash_message(commit.message or '')

    items[#items + 1] = {
      label = string.format('%s  %s', index, message),
      description = (branch or '') .. ' · ' .. age_display,
      value = { type = 'stash', commit = commit },
    }
  end
  return items
end

function StashView:_build_diff_file_entries_for_commit(commit)
  local repo = self._repo
  if not repo then return {} end

  local revision = commit.context and commit.context.revision
  if not revision then return {} end

  local file_diffs, err = repo:diff({
    type = 'range',
    from = revision .. '^',
    to = revision,
    layout_type = self._layout_type or 'unified',
  })

  if err then
    console.debug.error(string.format('[StashView] git diff failed for %s: %s', revision, err[1] or tostring(err)))
    return {}
  end

  if not file_diffs then return {} end

  local entries = {}
  for _, fd in ipairs(file_diffs) do
    entries[#entries + 1] = {
      type = 'diff_file',
      filename = fd.filename,
      filetype = fd.filetype,
      diff = fd.diff,
      original_lines = fd.original_lines,
      current_lines = fd.current_lines,
    }
  end

  return entries
end

function StashView:_set_hunk_entries(hunk_entries)
  if self._layout_type == self.LAYOUT_SPLIT then
    if self._previous_component and self._previous_component:is_valid() then
      local previous_entries = {}
      for _, entry in ipairs(hunk_entries) do
        local e = vim.tbl_extend('force', {}, entry)
        e.buftype = 'previous'
        previous_entries[#previous_entries + 1] = e
      end
      self._previous_component:set_props({ hunk_entries = previous_entries })
    end
    if self._current_component and self._current_component:is_valid() then
      local current_entries = {}
      for _, entry in ipairs(hunk_entries) do
        local e = vim.tbl_extend('force', {}, entry)
        e.buftype = 'current'
        current_entries[#current_entries + 1] = e
      end
      self._current_component:set_props({ hunk_entries = current_entries })
    end
  else
    if self._patch_component and self._patch_component:is_valid() then
      self._patch_component:set_props({ hunk_entries = hunk_entries })
    end
  end
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

  local entries = self:_build_diff_file_entries_for_commit(commit)

  if self._update_gen ~= gen then return end

  if revision then self._patch_cache[revision] = entries end

  self:_set_hunk_entries(entries)
end

function StashView:_refresh_stash_list()
  local repo = self._repo
  if not repo then return end

  self._patch_cache = {}

  local stashes, err = git_stash.list(repo:get_path())

  if err then
    console.debug.error(string.format('[StashView] list failed: %s', err[1] or tostring(err)))
    return
  end

  if not stashes or #stashes == 0 then
    self:destroy()
    return
  end

  local items = self:_build_items(stashes)

  if self._search_component and self._search_component:is_valid() then self._search_component:set_items(items) end
end

function StashView:_get_current_commit()
  if self._search_component and self._search_component:is_valid() then
    local item = self._search_component:get_selected_item()
    if item and item.value and item.value.commit then return item.value.commit end
  end
  return self._current_commit
end

function StashView:_get_current_revision()
  local commit = self:_get_current_commit()
  if not commit then return nil end
  return commit.context and commit.context.revision
end

function StashView:get_hunk_alignment()
  return stash_view_setting:get('hunk_alignment')
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
    component:hunk_down(self:get_hunk_alignment())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk({ index = index, count = count }) end
  end
end

function StashView:hunk_up()
  local component = self:_get_active_component()
  if component and component:is_valid() then
    component:hunk_up(self:get_hunk_alignment())
    local index, count = self:_get_current_mark_index(component)
    if index then statusline.set_hunk({ index = index, count = count }) end
  end
end

function StashView:_make_debounced(fn)
  local debounced, cleanup = event.debounce_async(fn, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, cleanup)
  return debounced
end

function StashView:_stash_action_with_revision(git_fn, success_prefix)
  local revision = self:_get_current_revision()
  if not revision then return end
  local _, err = git_fn(self._repo:get_path(), revision)
  if err then
    console.error(err[1] or tostring(err))
    return
  end
  console.info(success_prefix .. revision)
  self:_refresh_stash_list()
end

function StashView:setup_keymaps()
  local keymaps = stash_view_setting:get('keymaps')
  local scene_keymaps = scene_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      self:_set_keymap_all_diff_components('n', quit_key, function()
        self._component_manager:destroy()
      end)
    end
  end

  local action_keymaps = {
    {
      key = keymaps.add,
      fn = self:_make_debounced(function()
        local _, err = git_stash.add(self._repo:get_path())
        if err then
          console.error(err[1] or tostring(err))
          return
        end
        console.info('Changes stashed')
        self:_refresh_stash_list()
      end),
    },
    {
      key = keymaps.apply,
      fn = self:_make_debounced(function()
        self:_stash_action_with_revision(git_stash.apply, 'Stash applied: ')
      end),
    },
    {
      key = keymaps.pop,
      fn = self:_make_debounced(function()
        self:_stash_action_with_revision(git_stash.pop, 'Stash popped: ')
      end),
    },
    {
      key = keymaps.drop,
      fn = self:_make_debounced(function()
        self:_stash_action_with_revision(git_stash.drop, 'Stash dropped: ')
      end),
    },
    {
      key = keymaps.clear,
      fn = self:_make_debounced(function()
        local _, err = git_stash.clear(self._repo:get_path())
        if err then
          console.error(err[1] or tostring(err))
          return
        end
        console.info('All stashes cleared')
        self:destroy()
      end),
    },
  }

  for _, mapping in ipairs(action_keymaps) do
    local key = self:get_key(mapping.key)
    if key then self:_set_keymap_all_diff_components('n', key, mapping.fn) end
  end

  local down_fn = event.async(function()
    self:hunk_down()
  end)
  local up_fn = event.async(function()
    self:hunk_up()
  end)

  local down_key = self:get_key(hunks_keymaps.down)
  if down_key then self:_set_keymap_all_diff_components('n', down_key, down_fn) end

  local up_key = self:get_key(hunks_keymaps.up)
  if up_key then self:_set_keymap_all_diff_components('n', up_key, up_fn) end

  if self._search_component then
    self._search_component:set_keymap('i', '<C-j>', down_fn, 'Next hunk')
    self._search_component:set_keymap('i', '<C-k>', up_fn, 'Previous hunk')
  end
end

function StashView:_create_search_component(items)
  local on_move_fn, on_move_cleanup = event.debounce_trailing_async(function(item)
    if not item then return end
    local value = item.value
    if value and value.commit then self:_update_patch(value.commit) end
  end, self.DEBOUNCE_MS)
  table.insert(self._debounce_cleanups, on_move_cleanup)

  self._search_component = SearchComponent({
    items = items,
    popup = false,
    height = self.SEARCH_HEIGHT,
    placeholder = 'No stashes found',
    on_move = on_move_fn,
    on_close = function()
      self:destroy()
    end,
  })
end

function StashView:_mount(layout_spec)
  local wrapper = LayoutComponent({ spec = layout_spec })
  self._component_manager = ComponentManager()
  event.await()
  self._component_manager:render(Layout.screen(wrapper, { width = '100vw', height = '100vh' }))
  self:setup_keymaps()
end

function StashView:_create_unified(items)
  self._patch_component = PatchPreviewComponent({ hunk_entries = {}, focus = false })
  self:_create_search_component(items)

  self:_mount(LayoutSpec.vertical({
    LayoutSpec.view(self._patch_component),
    LayoutSpec.view(self._search_component),
  }))
end

function StashView:_create_split(items)
  self._previous_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = false,
    win_options = { scrollbind = true, cursorbind = true },
  })

  self._current_component = PatchPreviewComponent({
    hunk_entries = {},
    focus = false,
    win_options = { scrollbind = true, cursorbind = true },
  })

  self:_create_search_component(items)

  self:_mount(LayoutSpec.vertical({
    LayoutSpec.horizontal({
      LayoutSpec.view(self._previous_component, { flex = 1 }),
      LayoutSpec.view(self._current_component, { flex = 1 }),
    }),
    LayoutSpec.view(self._search_component),
  }))
end

function StashView:create(data)
  if not data then return false end
  if type(data) ~= 'table' then return false end
  if not data.stashes or type(data.stashes) ~= 'table' or #data.stashes == 0 then return false end

  self._data = data
  self._repo = data.repo
  self._layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  local items = self:_build_items(data.stashes)

  if self._layout_type == self.LAYOUT_SPLIT then
    self:_create_split(items)
  else
    self:_create_unified(items)
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

  if self._component_manager then
    self._component_manager:destroy()
    self._component_manager = nil
  end

  self._search_component = nil
  self._patch_component = nil
  self._previous_component = nil
  self._current_component = nil
end

return StashView
