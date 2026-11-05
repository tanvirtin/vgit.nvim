local lazy = require('vgit.core.lazy')

local ViewportComponent = lazy('vgit.ui.ViewportComponent')

local DiffViewportComponent = ViewportComponent:extend()

function DiffViewportComponent:on_mount()
  self:render()
  self:_ensure_renderer_attached()
end

function DiffViewportComponent:render() end

function DiffViewportComponent:get_lnum()
  return self:with_element(function(el)
    return el:get_lnum()
  end) or 1
end

function DiffViewportComponent:get_cursor()
  return self:with_element(function(el)
    return el:get_cursor()
  end) or { 1, 0 }
end

function DiffViewportComponent:get_line_count()
  return self:with_element(function(el)
    return el:get_line_count()
  end) or 0
end

function DiffViewportComponent:get_width()
  return self:with_element(function(el)
    return el:get_width()
  end) or 0
end

function DiffViewportComponent:get_height()
  return self:with_element(function(el)
    return el:get_height()
  end) or 0
end

function DiffViewportComponent:get_filetype()
  return self:with_element(function(el)
    return el:get_filetype()
  end) or ''
end

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

function DiffViewportComponent:render_viewport(top, bot) end

function DiffViewportComponent:_ensure_renderer_attached()
  self:ensure_renderer_attached(function()
    self:attach_to_renderer(function(top, bot)
      self:render_viewport(top, bot)
    end)
  end)
end

function DiffViewportComponent:ensure_window_options()
  self:with_element(function(el)
    el:sync_win_options()
  end)
  return self
end

return DiffViewportComponent
