local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ViewportComponent = lazy('vgit.ui.ViewportComponent')
local create_component_element = require('vgit.ui.create_component_element')
local element_delegation = require('vgit.ui.element_delegation')
local define_single_element_methods = element_delegation.define_single_element_methods
local define_getters_with_fallbacks = element_delegation.define_getters_with_fallbacks
local clean_nil_values = require('vgit.ui.Component').clean_nil_values

local DiffViewportComponent = ViewportComponent:extend()

function DiffViewportComponent:constructor(props)
  local instance = ViewportComponent.constructor(self, props)
  instance._element = nil
  return instance
end

-- Template methods for element configuration (override in subclasses)
function DiffViewportComponent:get_buf_options()
  return {}
end
function DiffViewportComponent:get_win_options()
  return {}
end
function DiffViewportComponent:get_win_plot()
  return nil
end
function DiffViewportComponent:get_layout_opts()
  return { flex = 1 }
end

function DiffViewportComponent:mount()
  if self._mounted then return end
  if not self._element then
    self._element = create_component_element({
      buf_options = self:get_buf_options(),
      win_options = self:get_win_options(),
      win_plot = self:get_win_plot(),
    }, self.props)
  end
  self._mounted = true
end

function DiffViewportComponent:on_mount()
  self:render()
  self:_ensure_renderer_attached()
end

function DiffViewportComponent:render() end

function DiffViewportComponent:set_props(updates, callback)
  if not updates then return end

  local prev_props = utils.object.clone(self.props)
  self.props = utils.object.extend(self.props, updates)

  clean_nil_values(self.props)

  if self._mounted then self:on_props(prev_props) end

  if callback then callback() end
end

function DiffViewportComponent:on_props(prev_props) end

function DiffViewportComponent:unmount()
  if not self._mounted then return end
  self:on_unmount()
  self._renderer_attached = false
  self._viewport_dirty = true
  self._last_top = nil
  self._last_bot = nil
  if self._element then
    self._element:unmount()
    self._element = nil
  end
  self._mounted = false
end

function DiffViewportComponent:on_unmount() end

function DiffViewportComponent:get_layout_spec()
  return LayoutSpec.view(self._element, self:get_layout_opts())
end

-- Generate shared element delegation methods (chainable + return-value)
-- Exclude getters that are overridden below with fallback defaults
define_single_element_methods(DiffViewportComponent, {
  exclude = {
    get_lines = true,
    get_lnum = true,
    get_cursor = true,
    get_line_count = true,
    get_width = true,
    get_height = true,
    get_filetype = true,
  },
})

-- Override getters with fallback defaults for viewport rendering
-- (viewport rendering runs hot and cannot nil-check every frame)
define_getters_with_fallbacks(DiffViewportComponent, {
  get_lnum = 1,
  get_cursor = { 1, 0 },
  get_line_count = 0,
  get_width = 0,
  get_height = 0,
  get_filetype = '',
})

function DiffViewportComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end) or self.state.lines or {}
end

function DiffViewportComponent:reset()
  self:clear_extmarks()
  self:clear_lines()
  self:reset_cursor()
  return self
end

-- Hunk navigation

function DiffViewportComponent:find_adjacent_mark_index(direction)
  local marks = self.state.marks
  if not marks or #marks == 0 then return nil end

  local lnum = self:get_lnum()

  if direction == 'next' then
    for i = 1, #marks do
      local mark = marks[i]
      if lnum >= mark.top and lnum <= mark.bot then
        return i + 1
      elseif mark.top > lnum then
        return i
      end
    end
    return 1
  end

  for i = #marks, 1, -1 do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then
      return i - 1
    elseif mark.top < lnum then
      return i
    end
  end
  return #marks
end

function DiffViewportComponent:move_to_hunk(mark_index, pos, offset)
  pos = pos or 'center'
  mark_index = mark_index or 1

  local marks = self.state.marks
  if not marks or #marks == 0 then return nil end

  if mark_index < 1 then
    mark_index = #marks
  elseif mark_index > #marks then
    mark_index = 1
  end

  local mark = marks[mark_index]
  if not mark then return nil end

  self:set_lnum(mark.top)
  if pos then self:scroll_to(pos, offset) end

  return mark
end

function DiffViewportComponent:hunk_down(pos, offset)
  local mark_index = self:find_adjacent_mark_index('next')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

function DiffViewportComponent:hunk_up(pos, offset)
  local mark_index = self:find_adjacent_mark_index('prev')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

function DiffViewportComponent:get_marks()
  return self.state.marks or {}
end

function DiffViewportComponent:get_hunks()
  return self.state.hunks or {}
end

function DiffViewportComponent:get_all_line_metadata()
  return self.state.line_metadata or {}
end

function DiffViewportComponent:get_hunk_under_cursor()
  local marks = self.state.marks
  local hunks = self.state.hunks
  if not marks or #marks == 0 or not hunks or #hunks == 0 then return nil end

  local lnum = self:get_lnum()

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then return hunks[i], i end
  end

  return nil
end

function DiffViewportComponent:get_current_mark_under_cursor()
  local marks = self.state.marks
  if not marks or #marks == 0 then return nil end

  local lnum = self:get_lnum()

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then return mark, i end
  end

  return nil
end

function DiffViewportComponent:get_relative_mark_index(lnum)
  local marks = self.state.marks
  if not marks or #marks == 0 then return 1 end

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top_relative and lnum <= mark.bot_relative then return i end
  end

  return 1
end

-- Viewport renderer (template method — override in subclasses)

function DiffViewportComponent:render_viewport(top, bot) end

function DiffViewportComponent:_ensure_renderer_attached()
  self:ensure_renderer_attached(function()
    self:attach_to_renderer(function(top, bot)
      self:render_viewport(top, bot)
    end)
  end)
end

-- Utility

function DiffViewportComponent:ensure_window_options()
  self:with_element(function(el)
    el:sync_win_options()
  end)
  return self
end

return DiffViewportComponent
