local fs = require('vgit.core.fs')
local utils = require('vgit.core.utils')
local Layout = require('vgit.ui.Layout')
local event = require('vgit.core.event')
local Object = require('vgit.core.Object')
local console = require('vgit.core.console')
local repository = require('vgit.git.repository')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local view_utils = require('vgit.features.screens.view_utils')
local hunks_setting = require('vgit.settings.hunks')
local project_diff_view_setting = require('vgit.settings.project_diff_view')
local ComponentManager = require('vgit.ui.ComponentManager')
local LayoutComponent = require('vgit.ui.components.LayoutComponent')
local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')

local ProjectDiffView = Object:extend()

ProjectDiffView.DEBOUNCE_MS = 100
ProjectDiffView.LAYOUT_SPLIT = 'split'
ProjectDiffView.LAYOUT_UNIFIED = 'unified'

function ProjectDiffView:constructor()
  return {
    data = nil,
    repo = nil,
    layout_type = nil,
    patch_component = nil,
    previous_component = nil,
    current_component = nil,
    component_manager = nil,
    patch_entries = {},
    line_to_file_map = {},
    debounce_cleanups = {},
  }
end

function ProjectDiffView:_handle_git_error(err, operation_name)
  return view_utils.handle_git_error(err, operation_name, 'ProjectDiffView')
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

  self.data = data
  return self:_create_view(data)
end

function ProjectDiffView:_get_diff_for_entry(repo, entry)
  local entry_type = entry.type
  local status = entry.status
  local filename = status.filename

  local diff_spec
  if entry_type == 'staged' then
    diff_spec = {
      type = 'range',
      filename = filename,
      from = 'HEAD',
      to = 'index',
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
    }
  end

  local diff_data, err = repo:diff(diff_spec, {})
  if err then
    console.debug.error(string.format('[ProjectDiffView] diff for %s failed: %s', filename, err))
    return nil
  end

  if not diff_data then
    console.debug.error(string.format('[ProjectDiffView] diff for %s returned nil', filename))
    return nil
  end

  return diff_data
end

function ProjectDiffView:_build_patch_entries(repo, data)
  local patch_entries = {}
  local line_to_file_map = {}
  local current_line = 1
  local files_processed = 0

  for _, section in ipairs(data.entries or {}) do
    for _, file_entry in ipairs(section.entries or {}) do
      local status = file_entry.status
      if not status then
        console.debug.error('[ProjectDiffView] file_entry has no status')
        goto continue
      end

      files_processed = files_processed + 1

      -- Use pre-computed diff when available (for historical diffs),
      -- otherwise generate diff for working tree changes
      local diff_data
      if file_entry.diff then
        diff_data = file_entry.diff
      else
        diff_data = self:_get_diff_for_entry(repo, file_entry)
      end

      if not diff_data then
        console.debug.error(string.format('[ProjectDiffView] no diff_data for %s', status.filename))
        goto continue
      end

      if not diff_data.hunks or #diff_data.hunks == 0 then
        console.debug.error(
          string.format(
            '[ProjectDiffView] no hunks for %s (hunks=%s)',
            status.filename,
            diff_data.hunks and #diff_data.hunks or 'nil'
          )
        )
        goto continue
      end

      local hunks = diff_data.hunks

      patch_entries[#patch_entries + 1] = {
        type = 'file_header',
        filename = status.filename,
        filetype = status.filetype,
        original_lines = diff_data.original_lines,
        current_lines = diff_data.current_lines,
      }

      line_to_file_map[current_line] = { filename = status.filename, lnum = 1 }
      current_line = current_line + 1
      line_to_file_map[current_line] = { filename = status.filename, lnum = 1 }
      current_line = current_line + 1
      line_to_file_map[current_line] = { filename = status.filename, lnum = 1 }
      current_line = current_line + 1

      for _, hunk in ipairs(hunks) do
        patch_entries[#patch_entries + 1] = {
          type = 'hunk',
          hunk = hunk,
          filetype = status.filetype,
          filename = status.filename,
        }

        if hunk.header then
          line_to_file_map[current_line] = {
            filename = status.filename,
            lnum = hunk.top or 1,
          }
          current_line = current_line + 1
        end

        local diff_line_offset = 0
        for _, line in ipairs(hunk.diff or {}) do
          local target_lnum = (hunk.top or 1) + diff_line_offset
          line_to_file_map[current_line] = {
            filename = status.filename,
            lnum = target_lnum,
          }
          current_line = current_line + 1

          local prefix = line:sub(1, 1)
          if prefix ~= '-' then diff_line_offset = diff_line_offset + 1 end
        end

        line_to_file_map[current_line] = { filename = status.filename, lnum = hunk.top or 1 }
        current_line = current_line + 1
      end

      ::continue::
    end
  end

  console.debug.info(
    string.format('[ProjectDiffView] processed %d files, got %d patch entries', files_processed, #patch_entries)
  )
  return patch_entries, line_to_file_map
end

function ProjectDiffView:_get_active_component()
  if self.layout_type == self.LAYOUT_SPLIT then return self.current_component end
  return self.patch_component
end

function ProjectDiffView:get_hunk_alignment()
  return view_utils.get_hunk_alignment()
end

function ProjectDiffView:hunk_up()
  local component = self:_get_active_component()
  if component and component:is_valid() then component:hunk_up(self:get_hunk_alignment()) end
end

function ProjectDiffView:hunk_down()
  local component = self:_get_active_component()
  if component and component:is_valid() then component:hunk_down(self:get_hunk_alignment()) end
end

function ProjectDiffView:jump_to_file()
  local component = self:_get_active_component()
  if not component or not component:is_valid() then return end

  local lnum = component:get_lnum()
  local file_info = self.line_to_file_map[lnum]

  console.debug.info(string.format(
    '[ProjectDiffView:jump_to_file] cursor_lnum=%d, mapped_lnum=%s, file=%s',
    lnum,
    file_info and file_info.lnum or 'nil',
    file_info and file_info.filename or 'nil'
  ))

  if not file_info or not file_info.filename then return end

  local filename = file_info.filename
  local target_lnum = file_info.lnum or 1

  self:destroy()
  event.await()

  fs.open(filename)

  local Window = require('vgit.core.Window')
  local window = Window(0)
  window:set_lnum(target_lnum)

  console.debug.info(string.format(
    '[ProjectDiffView:jump_to_file] opened file=%s, set lnum=%d',
    filename,
    target_lnum
  ))
end

function ProjectDiffView:get_key(keymap)
  return view_utils.get_key(keymap)
end

function ProjectDiffView:_set_keymap_on_component(component, mode, key, handler)
  if component and component:is_valid() then component:set_keymap({
    mode = mode,
    key = key,
  }, handler) end
end

function ProjectDiffView:_set_keymap_all_components(mode, key, handler)
  if self.layout_type == self.LAYOUT_SPLIT then
    self:_set_keymap_on_component(self.previous_component, mode, key, handler)
    self:_set_keymap_on_component(self.current_component, mode, key, handler)
  else
    self:_set_keymap_on_component(self.patch_component, mode, key, handler)
  end
end

function ProjectDiffView:setup_keymaps()
  local scene_setting = require('vgit.settings.scene')
  local display_service = require('vgit.ui.display_service')

  local scene_keymaps = scene_setting:get('keymaps')
  local project_diff_view_keymaps = project_diff_view_setting:get('keymaps')
  local hunks_keymaps = hunks_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      self:_set_keymap_all_components('n', quit_key, function()
        self.component_manager:destroy()
      end)
    end
  end

  local jump_key = self:get_key(project_diff_view_keymaps.jump)
  if jump_key then
    local jump_fn, jump_cleanup = event.debounce_async(function()
      self:jump_to_file()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, jump_cleanup)

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
end

function ProjectDiffView:_build_split_patch_entries(patch_entries)
  local prev_entries = {}
  local curr_entries = {}

  for _, entry in ipairs(patch_entries) do
    if entry.type == 'file_header' then
      prev_entries[#prev_entries + 1] = vim.tbl_extend('force', {}, entry)
      curr_entries[#curr_entries + 1] = vim.tbl_extend('force', {}, entry)
    elseif entry.type == 'hunk' then
      local hunk = entry.hunk
      local prev_diff = {}
      local curr_diff = {}

      for _, line in ipairs(hunk.diff or {}) do
        local prefix = line:sub(1, 1)
        if prefix == '-' then
          prev_diff[#prev_diff + 1] = line
          curr_diff[#curr_diff + 1] = ' '
        elseif prefix == '+' then
          prev_diff[#prev_diff + 1] = ' '
          curr_diff[#curr_diff + 1] = line
        else
          prev_diff[#prev_diff + 1] = line
          curr_diff[#curr_diff + 1] = line
        end
      end

      prev_entries[#prev_entries + 1] = {
        type = 'hunk',
        hunk = {
          header = hunk.header,
          diff = prev_diff,
          top = hunk.top,
          bot = hunk.bot,
        },
        filetype = entry.filetype,
        filename = entry.filename,
        original_lines = entry.original_lines,
        current_lines = entry.current_lines,
      }

      curr_entries[#curr_entries + 1] = {
        type = 'hunk',
        hunk = {
          header = hunk.header,
          diff = curr_diff,
          top = hunk.top,
          bot = hunk.bot,
        },
        filetype = entry.filetype,
        filename = entry.filename,
        original_lines = entry.original_lines,
        current_lines = entry.current_lines,
      }
    end
  end

  return prev_entries, curr_entries
end

function ProjectDiffView:_create_unified_view(patch_entries, line_to_file_map)
  self.patch_entries = patch_entries
  self.line_to_file_map = line_to_file_map

  self.patch_component = PatchPreviewComponent({
    patch_entries = patch_entries,
    focus = true,
  })

  self.component_manager = ComponentManager()
  event.await()
  self.component_manager:render(Layout.screen(self.patch_component, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()

  if self.patch_component and self.patch_component:is_valid() then self.patch_component:focus() end

  return true
end

function ProjectDiffView:_create_split_view(patch_entries, line_to_file_map)
  self.patch_entries = patch_entries
  self.line_to_file_map = line_to_file_map

  local prev_entries, curr_entries = self:_build_split_patch_entries(patch_entries)

  self.previous_component = PatchPreviewComponent({
    patch_entries = prev_entries,
    focus = false,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  self.current_component = PatchPreviewComponent({
    patch_entries = curr_entries,
    focus = true,
    win_options = {
      scrollbind = true,
      cursorbind = true,
    },
  })

  local wrapper = LayoutComponent({
    spec = LayoutSpec.horizontal({
      LayoutSpec.view(self.previous_component, { flex = 1 }),
      LayoutSpec.view(self.current_component, { flex = 1 }),
    }),
  })

  self.component_manager = ComponentManager()
  event.await()
  self.component_manager:render(Layout.screen(wrapper, {
    width = '100vw',
    height = '100vh',
  }))

  self:setup_keymaps()

  if self.current_component and self.current_component:is_valid() then self.current_component:focus() end

  return true
end

function ProjectDiffView:_create_view(data)
  local scene_setting = require('vgit.settings.scene')
  local layout_type = scene_setting:get('diff_preference') or self.LAYOUT_UNIFIED

  self.layout_type = layout_type

  local repo, err = repository.current()
  if err then
    console.debug.error(string.format('[ProjectDiffView] repository.current() failed: %s', err))
    return false
  end

  self.repo = repo

  local patch_entries, line_to_file_map = self:_build_patch_entries(repo, data)

  if #patch_entries == 0 then
    event.await()
    console.info('No changes to display')
    return false
  end

  if layout_type == self.LAYOUT_SPLIT then
    return self:_create_split_view(patch_entries, line_to_file_map)
  else
    return self:_create_unified_view(patch_entries, line_to_file_map)
  end
end

function ProjectDiffView:emit_cleanup_events()
  if self.patch_component then self.patch_component:component_will_unmount() end
  if self.previous_component then self.previous_component:component_will_unmount() end
  if self.current_component then self.current_component:component_will_unmount() end
end

function ProjectDiffView:destroy()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
  self:emit_cleanup_events()
  if self.component_manager then self.component_manager:destroy() end
end

return ProjectDiffView
