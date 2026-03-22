local lazy = require('vgit.core.lazy')
local Component = lazy('vgit.ui.Component')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local LineNumberCalculator = lazy('vgit.ui.calculators.LineNumberCalculator')

local SplitDiffComponent = Component({
  children = {
    previous = DiffComponent,
    current = DiffComponent,
  },

  on_mount = function(self)
    self.children.previous:set_win_option('scrollbind', true)
    self.children.previous:set_win_option('cursorbind', true)
    self.children.current:set_win_option('scrollbind', true)
    self.children.current:set_win_option('cursorbind', true)

    if self.props.win_options then
      for k, v in pairs(self.props.win_options) do
        self.children.previous:set_win_option(k, v)
        self.children.current:set_win_option(k, v)
      end
    end

    self:render()
  end,

  on_props = function(self, prev_props)
    if self.props.diff ~= prev_props.diff or self.props.filetype ~= prev_props.filetype then self:render() end
  end,
})

function SplitDiffComponent:constructor(props)
  local instance = SplitDiffComponent.super.constructor(self, props)
  instance.children = {}
  instance._line_number_calculator = LineNumberCalculator()
  return instance
end

function SplitDiffComponent:get_initial_state()
  return {
    previous_lines = {},
    current_lines = {},
  }
end

function SplitDiffComponent:_for_both(fn)
  if self.children.previous then fn(self.children.previous) end
  if self.children.current then fn(self.children.current) end
end

function SplitDiffComponent:calculate_split_line_numbers(diff)
  local current_lnum_change_map = {}
  local previous_lnum_change_map = {}

  for i = 1, #diff.lnum_changes do
    local lnum_change = diff.lnum_changes[i]

    if lnum_change.buftype == 'current' then
      current_lnum_change_map[lnum_change.lnum] = lnum_change
    elseif lnum_change.buftype == 'previous' then
      previous_lnum_change_map[lnum_change.lnum] = lnum_change
    end
  end

  local previous_lines, previous_changes =
    self._line_number_calculator:calculate_split_previous_line_numbers(diff, previous_lnum_change_map)
  local current_lines, current_changes =
    self._line_number_calculator:calculate_split_current_line_numbers(diff, current_lnum_change_map)

  return {
    previous = { lines = previous_lines, changes = previous_changes },
    current = { lines = current_lines, changes = current_changes },
  }
end

function SplitDiffComponent:render()
  local diff = self.props.diff

  if not diff then
    self.state.previous_lines = {}
    self.state.current_lines = {}
    self:_for_both(function(c)
      c:set_props({
        diff = vim.NIL,
        filetype = vim.NIL,
        _split_line_numbers = vim.NIL,
        _split_lines_changes = vim.NIL,
      })
    end)
    return
  end

  local result = self:calculate_split_line_numbers(diff)

  local previous_diff = vim.tbl_extend('force', diff, {
    lines = diff.previous_lines or {},
  })

  local current_diff = vim.tbl_extend('force', diff, {
    lines = diff.current_lines or {},
  })

  if self.children.previous then
    self.children.previous:set_props({
      diff = previous_diff,
      filetype = self.props.filetype,
      _split_line_numbers = result.previous.lines,
      _split_lines_changes = result.previous.changes,
    })
  end
  if self.children.current then
    self.children.current:set_props({
      diff = current_diff,
      filetype = self.props.filetype,
      _split_line_numbers = result.current.lines,
      _split_lines_changes = result.current.changes,
    })
  end

  self.state.previous_lines = diff.previous_lines or {}
  self.state.current_lines = diff.current_lines or {}
end

function SplitDiffComponent:layout(spec)
  return spec.horizontal({
    spec.view(self.children.previous, { flex = 1 }),
    spec.view(self.children.current, { flex = 1 }),
  })
end

function SplitDiffComponent:get_component(id)
  if id == 'current' then
    return self.children.current
  elseif id == 'previous' then
    return self.children.previous
  end
  return nil
end

-- Broadcast to both children

function SplitDiffComponent:enable_cursorline()
  self:_for_both(function(c)
    c:enable_cursorline()
  end)
end

function SplitDiffComponent:disable_cursorline()
  self:_for_both(function(c)
    c:disable_cursorline()
  end)
end

function SplitDiffComponent:set_filetype(filetype)
  self:_for_both(function(c)
    c:set_filetype(filetype)
  end)
end

function SplitDiffComponent:clear_extmarks()
  self:_for_both(function(c)
    c:clear_extmarks()
  end)
end

function SplitDiffComponent:render_folds()
  self:_for_both(function(c)
    c:render_folds()
  end)
end

function SplitDiffComponent:clear_folds()
  self:_for_both(function(c)
    c:clear_folds()
  end)
end

function SplitDiffComponent:on(event_name, callback)
  self:_for_both(function(c)
    c:on(event_name, callback)
  end)
end

function SplitDiffComponent:set_keymap(mode_or_opts, key_or_callback, handler, desc)
  self:_for_both(function(c)
    c:set_keymap(mode_or_opts, key_or_callback, handler, desc)
  end)
end

function SplitDiffComponent:reset_cursor()
  self:_for_both(function(c)
    c:reset_cursor()
  end)
end

function SplitDiffComponent:attach_to_renderer(callback)
  self:_for_both(function(c)
    c:attach_to_renderer(callback)
  end)
end

-- Delegate to current child

function SplitDiffComponent:get_lnum()
  if self.children.current then return self.children.current:get_lnum() end
  return 1
end

function SplitDiffComponent:get_filetype()
  if self.children.current then return self.children.current:get_filetype() end
  return ''
end

function SplitDiffComponent:get_marks()
  if self.children.current then return self.children.current:get_marks() end
  return {}
end

function SplitDiffComponent:get_hunks()
  if self.children.current then return self.children.current:get_hunks() end
  return {}
end

function SplitDiffComponent:get_hunk_under_cursor()
  if self.children.current then return self.children.current:get_hunk_under_cursor() end
  return nil
end

function SplitDiffComponent:get_current_mark_under_cursor()
  if self.children.current then return self.children.current:get_current_mark_under_cursor() end
  return nil
end

function SplitDiffComponent:get_all_line_metadata()
  if self.children.current then return self.children.current:get_all_line_metadata() end
  return {}
end

function SplitDiffComponent:get_relative_mark_index(lnum)
  if self.children.current then return self.children.current:get_relative_mark_index(lnum) end
  return 1
end

-- Custom implementations

function SplitDiffComponent:set_lines(previous_lines, current_lines)
  self:set_state({
    previous_lines = previous_lines or {},
    current_lines = current_lines or {},
  })
  return self
end

function SplitDiffComponent:clear_lines()
  self:_for_both(function(c)
    c:clear_lines():disable_cursorline()
  end)
  self.state.previous_lines = {}
  self.state.current_lines = {}
end

function SplitDiffComponent:set_lnum(lnum, position)
  self:_for_both(function(c)
    c:set_lnum(lnum)
    if position then c:scroll_to(position) end
  end)
end

function SplitDiffComponent:is_valid()
  return (self.children.previous and self.children.previous:is_valid())
    and (self.children.current and self.children.current:is_valid())
end

function SplitDiffComponent:hunk_down(pos, offset)
  if self.children.current then return self.children.current:hunk_down(pos, offset) end
  return nil
end

function SplitDiffComponent:hunk_up(pos, offset)
  if self.children.current then return self.children.current:hunk_up(pos, offset) end
  return nil
end

function SplitDiffComponent:move_to_hunk(mark_index, pos, offset)
  if not self.children.current then return nil end

  local mark = self.children.current:move_to_hunk(mark_index, pos, offset)

  if mark and self.children.previous then
    self.children.previous:set_lnum(mark.top)
    if pos then self.children.previous:scroll_to(pos, offset) end
  end

  return mark
end

function SplitDiffComponent:reset()
  self:_for_both(function(c)
    c:reset()
  end)
  return self
end

function SplitDiffComponent:call(callback)
  if self.children.current and self.children.current:is_valid() and callback then
    self.children.current:call(callback)
  end
end

return SplitDiffComponent
