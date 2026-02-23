local lazy = require('vgit.core.lazy')
local Layout = lazy('vgit.ui.Layout')
local Object = lazy('vgit.core.Object')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local scene_setting = lazy('vgit.settings.scene')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local BorderComponent = lazy('vgit.ui.components.BorderComponent')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local SplitDiffComponent = lazy('vgit.ui.components.SplitDiffComponent')
local status_diff_view_setting = lazy('vgit.settings.status_diff_view')

local HunkLens = Object:extend()

function HunkLens:constructor()
  return {
    active = false,
    diff_component = nil,
    component_manager = nil,
  }
end

function HunkLens:prev_hunk()
  self.diff_component:hunk_up('center')
end

function HunkLens:next_hunk()
  self.diff_component:hunk_down('center')
end

function HunkLens:create_diff_component(diff_data, filename, filetype, layout_type)
  local props = {
    diff = diff_data,
    filename = filename,
    filetype = filetype,
  }

  if layout_type == 'unified' then return DiffComponent(props) end
  return SplitDiffComponent(props)
end

function HunkLens:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
end

function HunkLens:setup_keymaps()
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = status_diff_view_setting:get('keymaps')

  local quit_key = self:get_key(scene_keymaps.quit)
  if quit_key then
    self.diff_component:set_keymap({
      mode = 'n',
      key = quit_key,
    }, function()
      self.component_manager:destroy()
    end)
  end

  local prev_key = self:get_key(diff_keymaps.previous)
  if prev_key then
    local prev_fn = event.async(function()
      self:prev_hunk()
    end)
    self.diff_component:set_keymap({
      mode = 'n',
      key = prev_key,
    }, prev_fn)
  end

  local next_key = self:get_key(diff_keymaps.next)
  if next_key then
    local next_fn = event.async(function()
      self:next_hunk()
    end)
    self.diff_component:set_keymap({
      mode = 'n',
      key = next_key,
    }, next_fn)
  end
end

function HunkLens:create(data)
  if not data then
    console.error('[HunkLens] No data provided')
    return false
  end

  if self.active then self:hide() end

  if not data.diff then
    console.info('[HunkLens] No hunk at cursor position')
    return false
  end

  if not data.diff.marks or #data.diff.marks == 0 then
    console.info('[HunkLens] No hunks found in file')
    return false
  end

  if not data.target_hunk_index or data.target_hunk_index == 0 then
    console.info('[HunkLens] No hunk at cursor position')
    return false
  end

  local layout_type = data.layout_type or 'unified'

  self.diff_component = self:create_diff_component(data.diff, data.filename, data.filetype, layout_type)

  local center_border = BorderComponent()
  local bottom_border = BorderComponent()

  local wrapper = LayoutComponent({
    spec = LayoutSpec.vertical({
      LayoutSpec.view(center_border, { height = 1 }),
      LayoutSpec.view(self.diff_component, { flex = 1 }),
      LayoutSpec.view(bottom_border, { height = 1 }),
    }),
  })

  self.component_manager = ComponentManager()
  self.component_manager:render(Layout.lens(wrapper, {
    relative = 'cursor',
    height = '35vh',
  }))

  local target_hunk = data.target_hunk_index or 1
  self.diff_component:move_to_hunk(target_hunk, 'center')

  self:setup_keymaps()

  self.active = true
  return true
end

function HunkLens:emit_cleanup_events()
  self.diff_component:component_will_unmount()
end

function HunkLens:hide()
  if not self.active then return end

  self:emit_cleanup_events()
  self.component_manager:destroy()
  self.active = false
end

function HunkLens:destroy()
  self:hide()
end

function HunkLens:on(event_name, callback)
  self.component_manager:on(event_name, callback)
end

function HunkLens:set_keymap(configs)
  self.component_manager:set_keymap(configs)
end

return HunkLens
