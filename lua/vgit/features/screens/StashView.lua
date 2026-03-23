local lazy = require('vgit.core.lazy')

local View = lazy('vgit.ui.View')
local event = lazy('vgit.core.event')
local keymap = lazy('vgit.core.keymap')
local console = lazy('vgit.core.console')
local git_stash = lazy('vgit.git.git_stash')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local stash_view_setting = lazy('vgit.settings.stash_view')
local SearchComponent = lazy('vgit.ui.components.SearchComponent')
local PatchPreviewComponent = lazy('vgit.ui.components.PatchPreviewComponent')

local StashView = View:extend()

StashView.DEBOUNCE_MS = 200
StashView.SEARCH_HEIGHT = 10
StashView.LAYOUT_SPLIT = 'split'
StashView.LAYOUT_UNIFIED = 'unified'

function StashView:constructor()
  local instance = View.constructor(self)
  instance._data = nil
  instance._repo = nil
  instance._layout_type = nil
  instance._search_component = nil
  instance._patch_component = nil
  instance._previous_component = nil
  instance._current_component = nil
  instance._current_commit = nil
  instance._patch_cache = {}
  instance._update_gen = 0
  return instance
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
      value = { type = 'stash', data = commit },
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
    if item and item.value and item.value.data then return item.value.data end
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

function StashView:get_hunk_alignment_offset()
  return stash_view_setting:get('hunk_alignment_offset') or 0
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

  self:_setup_quit_keymap()

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
    local key = keymap.get_key(mapping.key)
    if key then self:_set_keymap_all_components('n', key, mapping.fn) end
  end

  self:_setup_hunk_navigation_keymaps()

  if self._search_component then
    local down_fn = event.async(function()
      self:hunk_down()
    end)
    local up_fn = event.async(function()
      self:hunk_up()
    end)
    self._search_component:set_keymap({ mode = 'i', key = '<C-j>' }, down_fn)
    self._search_component:set_keymap({ mode = 'i', key = '<C-k>' }, up_fn)
  end
end

function StashView:_create_search_component(items)
  local on_move_fn, on_move_cleanup = event.debounce_trailing_async(function(item)
    if not item then return end
    local value = item.value
    if value and value.data then self:_update_patch(value.data) end
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

function StashView:_mount(children)
  event.await()
  self:_render(LayoutSpec.screen(children))
  self:setup_keymaps()
end

function StashView:_mount_unified_layout(items)
  self._patch_component = PatchPreviewComponent({ hunk_entries = {}, focus = false })
  self:_create_search_component(items)

  self:_mount({
    LayoutSpec.view(self._patch_component),
    LayoutSpec.view(self._search_component),
  })
end

function StashView:_mount_split_layout(items)
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

  self:_mount({
    LayoutSpec.horizontal({
      LayoutSpec.view(self._previous_component, { flex = 1 }),
      LayoutSpec.view(self._current_component, { flex = 1 }),
    }),
    LayoutSpec.view(self._search_component),
  })
end

function StashView:_create_view(data)
  local items = self:_build_items(data.stashes)

  if self._layout_type == self.LAYOUT_SPLIT then
    self:_mount_split_layout(items)
  else
    self:_mount_unified_layout(items)
  end

  return true
end

function StashView:create(data)
  if not data then return false end
  if type(data) ~= 'table' then return false end
  if not data.stashes or type(data.stashes) ~= 'table' or #data.stashes == 0 then return false end

  self._data = data
  self._repo = data.repo
  self._layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  return self:_create_view(data)
end

return StashView
