local lazy = require('vgit.core.lazy')

local keymap = lazy('vgit.core.keymap')
local View = lazy('vgit.ui.View')
local event = lazy('vgit.core.event')
local console = lazy('vgit.core.console')
local LayoutBounds = lazy('vgit.ui.layout.LayoutBounds')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local hunk_lens_setting = lazy('vgit.settings.hunk_lens')
local BorderComponent = lazy('vgit.ui.components.BorderComponent')
local hunks_setting = lazy('vgit.settings.hunks')

local HunkLensView = View:extend()

function HunkLensView:constructor()
  local instance = View.constructor(self)
  instance._diff_component = nil
  return instance
end

function HunkLensView:hunk_up()
  self._diff_component:hunk_up(hunk_lens_setting:get('hunk_alignment'), hunk_lens_setting:get('hunk_alignment_offset'))
end

function HunkLensView:hunk_down()
  self._diff_component:hunk_down(
    hunk_lens_setting:get('hunk_alignment'),
    hunk_lens_setting:get('hunk_alignment_offset')
  )
end

function HunkLensView:setup_keymaps()
  local hunk_keymaps = hunks_setting:get('keymaps')

  self:_setup_quit_keymap()

  local prev_key = keymap.get_key(hunk_keymaps.up)
  if prev_key then
    local prev_fn = event.async(function()
      self:hunk_up()
    end)
    self._diff_component:set_keymap({
      mode = 'n',
      key = prev_key,
    }, prev_fn)
  end

  local next_key = keymap.get_key(hunk_keymaps.down)
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

function HunkLensView:create(data)
  if not data then
    console.error('[HunkLensView] No data provided')
    return false
  end

  if self._context then self:destroy() end

  if not data.diff then
    console.info('[HunkLensView] No hunk at cursor position')
    return false
  end

  if not data.diff.marks or #data.diff.marks == 0 then
    console.info('[HunkLensView] No hunks found in file')
    return false
  end

  if not data.target_hunk_index or data.target_hunk_index == 0 then
    console.info('[HunkLensView] No hunk at cursor position')
    return false
  end

  local layout_type = data.layout_type or 'unified'

  local border_lines = 2
  local target_mark = data.diff.marks[data.target_hunk_index]
  local hunk_lines = target_mark.bot - target_mark.top + 1
  local default_height = LayoutBounds.convert_dimension('35vh')
  local max_height = vim.o.lines - 3
  local height = math.min(math.max(default_height, hunk_lines + border_lines), max_height)

  self._diff_component = self:_create_diff_component({
    diff = data.diff,
    filename = data.filename,
    filetype = data.filetype,
  }, layout_type)

  local center_border = BorderComponent()
  local bottom_border = BorderComponent()

  self:_render(LayoutSpec.lens(
    LayoutSpec.vertical({
      LayoutSpec.view(center_border, { height = 1 }),
      LayoutSpec.view(self._diff_component, { flex = 1 }),
      LayoutSpec.view(bottom_border, { height = 1 }),
    }),
    {
      height = height,
    }
  ))

  local hunk_alignment = hunk_lens_setting:get('hunk_alignment')
  local hunk_alignment_offset = hunk_lens_setting:get('hunk_alignment_offset')
  self._diff_component:move_to_hunk(data.target_hunk_index, hunk_alignment, hunk_alignment_offset)

  self:setup_keymaps()

  return true
end

return HunkLensView
