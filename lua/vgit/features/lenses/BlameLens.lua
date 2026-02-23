local lazy = require('vgit.core.lazy')
local Layout = lazy('vgit.ui.Layout')
local Object = lazy('vgit.core.Object')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local console = lazy('vgit.core.console')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ComponentManager = lazy('vgit.ui.ComponentManager')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local BorderComponent = lazy('vgit.ui.components.BorderComponent')
local LayoutComponent = lazy('vgit.ui.components.LayoutComponent')
local BlameInfoComponent = lazy('vgit.ui.components.BlameInfoComponent')
local SplitDiffComponent = lazy('vgit.ui.components.SplitDiffComponent')
local scene_setting = lazy('vgit.settings.scene')
local status_diff_view_setting = lazy('vgit.settings.status_diff_view')

local BlameLens = Object:extend()

function BlameLens:constructor()
  return {
    blame = nil,
    buffer = nil,
    blame_info_component = nil,
    diff_component = nil,
    component_manager = nil,
    pending_quit_key = nil,
  }
end

function BlameLens:prev_hunk()
  self.diff_component:hunk_up('top')
end

function BlameLens:next_hunk()
  self.diff_component:hunk_down('top')
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
        self.pending_quit_key = {
          key = quit_key,
        }
      end
    end
  end

  self:setup_hunk_keymaps()
end

function BlameLens:setup_hunk_keymaps()
  if not self.diff_component then return end

  local keymaps = status_diff_view_setting:get('keymaps')

  if not keymaps then return end

  local prev_key = self:get_key(keymaps.previous)
  if prev_key then
    local prev_fn = event.async(function()
      self:prev_hunk()
    end)
    self.diff_component:set_keymap({
      mode = 'n',
      key = prev_key,
    }, prev_fn)
  end

  local next_key = self:get_key(keymaps.next)
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
