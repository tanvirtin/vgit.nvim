local lazy = require('vgit.core.lazy')

local keymap = lazy('vgit.core.keymap')
local View = lazy('vgit.ui.View')
local event = lazy('vgit.core.event')
local Buffer = lazy('vgit.core.Buffer')
local console = lazy('vgit.core.console')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local BorderComponent = lazy('vgit.ui.components.BorderComponent')
local BlameInfoComponent = lazy('vgit.ui.components.BlameInfoComponent')
local hunks_setting = lazy('vgit.settings.hunks')

local BlameLensView = View:extend()

function BlameLensView:constructor()
  local instance = View.constructor(self)
  instance._blame = nil
  instance._buffer = nil
  instance._blame_info_component = nil
  instance._diff_component = nil
  return instance
end

function BlameLensView:hunk_up()
  if not self._diff_component then return end
  self._diff_component:hunk_up('top')
end

function BlameLensView:hunk_down()
  if not self._diff_component then return end
  self._diff_component:hunk_down('top')
end

function BlameLensView:create(data)
  if not data or not data.blame then
    console.error('[BlameLensView] No blame data provided')
    return false
  end

  self._blame = data.blame
  local layout_type = data.layout_type or 'unified'

  local buffer = Buffer(0)
  self._buffer = buffer

  self._blame_info_component = BlameInfoComponent({
    blame = self._blame,
  })

  local diff_component = nil
  if data.diff and not data.is_uncommitted then
    diff_component = self:_create_diff_component({
      diff = data.diff,
      filetype = data.filetype,
    }, layout_type)
    self._diff_component = diff_component
  end

  local top_border = BorderComponent({
    text = string.format('%s (Blame)', buffer:get_name()),
  })
  local bottom_border = BorderComponent()

  local layout_children = {
    LayoutSpec.view(top_border, { height = 1 }),
    LayoutSpec.view(self._blame_info_component, { height = 3 }),
  }

  if diff_component then table.insert(layout_children, LayoutSpec.view(diff_component, { flex = 1 })) end

  table.insert(layout_children, LayoutSpec.view(bottom_border, { height = 1 }))

  local height = diff_component and '35vh' or '5'

  self:_render(LayoutSpec.lens(LayoutSpec.vertical(layout_children), {
    height = height,
  }))

  if data.diff and data.blame and data.blame.lnum then self:set_relative_lnum(data.blame.lnum, data.diff) end

  self:setup_keymaps()

  return true
end

function BlameLensView:setup_keymaps()
  self:_setup_quit_keymap()
  self:setup_hunk_keymaps()
end

function BlameLensView:setup_hunk_keymaps()
  if not self._diff_component then return end

  local keymaps = hunks_setting:get('keymaps')

  if not keymaps then return end

  local prev_key = keymap.get_key(keymaps.up)
  if prev_key then
    local prev_fn = event.async(function()
      self:hunk_up()
    end)
    self._diff_component:set_keymap({
      mode = 'n',
      key = prev_key,
    }, prev_fn)
  end

  local next_key = keymap.get_key(keymaps.down)
  if next_key then
    local next_fn = event.async(function()
      self:hunk_down()
    end)
    self._diff_component:set_keymap({
      mode = 'n',
      key = next_key,
    }, next_fn)
  end
end

function BlameLensView:set_relative_lnum(lnum, diff)
  if not diff or not self._diff_component then return end

  local adjusted_lnum = lnum

  if diff.lnum_changes then
    for i = 1, #diff.lnum_changes do
      local lnum_change = diff.lnum_changes[i]

      if
        lnum_change.buftype == 'current'
        and (lnum_change.type == 'void' or lnum_change.type == 'remove')
        and adjusted_lnum >= lnum_change.lnum
      then
        adjusted_lnum = adjusted_lnum + 1
      end
    end
  end

  local target_hunk = self._diff_component:get_relative_mark_index(adjusted_lnum)
  if target_hunk then self._diff_component:move_to_hunk(target_hunk, 'top') end

  vim.schedule(function()
    if self._diff_component then self._diff_component:set_lnum(adjusted_lnum) end
  end)
end

return BlameLensView
