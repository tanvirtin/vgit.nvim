local Layout = require('vgit.ui.Layout')
local Object = require('vgit.core.Object')
local event = require('vgit.core.event')
local Buffer = require('vgit.core.Buffer')
local console = require('vgit.core.console')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local ComponentManager = require('vgit.ui.ComponentManager')
local DiffComponent = require('vgit.ui.components.DiffComponent')
local BorderComponent = require('vgit.ui.components.BorderComponent')
local LayoutComponent = require('vgit.ui.components.LayoutComponent')
local BlameInfoComponent = require('vgit.ui.components.BlameInfoComponent')
local SplitDiffComponent = require('vgit.ui.components.SplitDiffComponent')

local BlameLens = Object:extend()

BlameLens.DEBOUNCE_MS = 100

function BlameLens:constructor()
  return {
    blame = nil,
    buffer = nil,
    blame_info_component = nil,
    diff_component = nil,
    component_manager = nil,
    _pending_quit_key = nil,
    debounce_cleanups = {},
  }
end

function BlameLens:hunk_up()
  self.diff_component:prev('top')
end

function BlameLens:hunk_down()
  self.diff_component:next('top')
end

function BlameLens:create(data)
  if not data or not data.blame then
    console.error('[BlameLens] No blame data provided')
    return false
  end

  self.component_manager = ComponentManager()
  self.blame = data.blame
  local layout_type = data.layout_type or 'unified'

  local buffer = Buffer(0)
  self.buffer = buffer

  self.blame_info_component = BlameInfoComponent({
    blame = self.blame,
  })

  local diff_component = nil
  if data.diff and not data.is_uncommitted then
    if layout_type == 'split' then
      diff_component = SplitDiffComponent({
        diff = data.diff,
        filetype = data.filetype or 'text',
      })
    else
      diff_component = DiffComponent({
        diff = data.diff,
        filetype = data.filetype or 'text',
      })
    end
    self.diff_component = diff_component
  end

  local top_border = BorderComponent({
    text = string.format('%s (Blame)', buffer:get_name()),
  })
  local bottom_border = BorderComponent()

  local layout_children = {
    LayoutSpec.view(top_border, { height = 1 }),
    LayoutSpec.view(self.blame_info_component, { height = 3 }),
  }

  if diff_component then table.insert(layout_children, LayoutSpec.view(diff_component, { flex = 1 })) end

  table.insert(layout_children, LayoutSpec.view(bottom_border, { height = 1 }))

  local wrapper = LayoutComponent({
    spec = LayoutSpec.vertical(layout_children),
  })

  local height = diff_component and '35vh' or '5'

  self.component_manager:render(Layout.lens(wrapper, {
    height = height,
    relative = 'cursor',
    zindex = 2,
  }))

  if data.diff and data.blame and data.blame.lnum then self:set_relative_lnum(data.blame.lnum, data.diff) end

  self:setup_keymaps()

  return true
end

function BlameLens:get_key(keymap)
  if type(keymap) == 'string' then
    return keymap
  elseif type(keymap) == 'table' then
    return keymap.key
  end
end

function BlameLens:setup_keymaps()
  local scene_setting = require('vgit.settings.scene')
  local scene_keymaps = scene_setting:get('keymaps')

  if scene_keymaps and scene_keymaps.quit then
    local quit_key = self:get_key(scene_keymaps.quit)
    if quit_key then
      if self.diff_component then
        self.diff_component:set_keymap({
          mode = 'n',
          key = quit_key,
        }, function()
          self.component_manager:destroy()
        end)
      else
        self._pending_quit_key = {
          key = quit_key,
        }
      end
    end
  end

  self:_setup_hunk_keymaps()
end

function BlameLens:_setup_hunk_keymaps()
  if not self.diff_component then return end

  local diff_view_setting = require('vgit.settings.diff_view')
  local keymaps = diff_view_setting:get('keymaps')

  if not keymaps then return end

  local hunk_up_key = self:get_key(keymaps.hunk_up)
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

  local hunk_down_key = self:get_key(keymaps.hunk_down)
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

function BlameLens:set_relative_lnum(lnum, diff)
  if not diff or not self.diff_component then return end

  local adjusted_lnum = lnum

  if diff.lnum_changes then
    for i = 1, #diff.lnum_changes do
      local lnum_change = diff.lnum_changes[i]
      local l = lnum_change.lnum
      local change_type = lnum_change.type
      local buftype = lnum_change.buftype

      if buftype == 'current' and (change_type == 'void' or change_type == 'remove') and adjusted_lnum >= l then
        adjusted_lnum = adjusted_lnum + 1
      end
    end
  end

  if self.diff_component and self.diff_component.move_to_hunk then
    local target_hunk = self.diff_component:get_relative_mark_index(adjusted_lnum)
    if target_hunk then self.diff_component:move_to_hunk(target_hunk, 'top') end
  end

  vim.schedule(function()
    if self.diff_component then self.diff_component:set_lnum(adjusted_lnum) end
  end)
end

function BlameLens:emit_cleanup_events()
  self.blame_info_component:component_will_unmount()
  if self.diff_component then self.diff_component:component_will_unmount() end
end

function BlameLens:destroy()
  for _, cleanup in ipairs(self.debounce_cleanups) do
    cleanup()
  end
  self.debounce_cleanups = {}
  self:emit_cleanup_events()
  self.component_manager:destroy()
end

function BlameLens:on(event_name, callback)
  self.component_manager:on(event_name, callback)
end

function BlameLens:set_keymap(configs)
  self.component_manager:set_keymap(configs)
end

return BlameLens
