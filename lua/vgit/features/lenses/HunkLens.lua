local Layout = require('vgit.ui.Layout')
local Object = require('vgit.core.Object')
local event = require('vgit.core.event')
local console = require('vgit.core.console')
local scene_setting = require('vgit.settings.scene')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local ComponentManager = require('vgit.ui.ComponentManager')
local DiffComponent = require('vgit.ui.components.DiffComponent')
local BorderComponent = require('vgit.ui.components.BorderComponent')
local LayoutComponent = require('vgit.ui.components.LayoutComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

local HunkLens = Object:extend()

HunkLens.DEBOUNCE_MS = 100

function HunkLens:constructor()
  return {
    active = false,
    diff_component = nil,
    component_manager = nil,
    debounce_cleanups = {},
  }
end

function HunkLens:hunk_up()
  self.diff_component:prev('center')
end

function HunkLens:hunk_down()
  self.diff_component:next('center')
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
  local diff_view_setting = require('vgit.settings.diff_view')
  local scene_keymaps = scene_setting:get('keymaps')
  local diff_keymaps = diff_view_setting:get('keymaps')

  local quit_key = self:get_key(scene_keymaps.quit)
  if quit_key then
    self.diff_component:set_keymap({
      mode = 'n',
      key = quit_key,
    }, function()
      self.component_manager:destroy()
    end)
  end

  local hunk_up_key = self:get_key(diff_keymaps.hunk_up)
  if hunk_up_key then
    local hunk_up_fn, hunk_up_cleanup = event.debounce_async(function()
      self:hunk_up()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, hunk_up_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_up_key,
      },
      hunk_up_fn
    )
  end

  local hunk_down_key = self:get_key(diff_keymaps.hunk_down)
  if hunk_down_key then
    local hunk_down_fn, hunk_down_cleanup = event.debounce_async(function()
      self:hunk_down()
    end, self.DEBOUNCE_MS)
    table.insert(self.debounce_cleanups, hunk_down_cleanup)
    self.diff_component:set_keymap(
      {
        mode = 'n',
        key = hunk_down_key,
      },
      hunk_down_fn
    )
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

  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}

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
