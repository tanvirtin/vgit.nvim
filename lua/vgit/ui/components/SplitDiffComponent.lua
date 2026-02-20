local vim = vim
local lazy = require('vgit.core.lazy')
local Component = lazy('vgit.ui.Component')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')
local DiffComponent = lazy('vgit.ui.components.DiffComponent')
local LineNumberCalculator = lazy('vgit.ui.calculators.LineNumberCalculator')

local SplitDiffComponent = Component:extend()

function SplitDiffComponent:constructor(props)
  local instance = Component.constructor(self, props)
  instance._previous_component = nil
  instance._current_component = nil
  instance._line_number_calculator = LineNumberCalculator()
  return instance
end

function SplitDiffComponent:_for_both(fn)
  if self._previous_component then fn(self._previous_component) end
  if self._current_component then fn(self._current_component) end
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

function SplitDiffComponent:get_initial_state()
  return {
    previous_lines = {},
    current_lines = {},
  }
end

function SplitDiffComponent:should_component_update(next_props, next_state)
  -- Only update if diff or filetype actually changed
  if self.props.diff ~= next_props.diff then return true end
  if self.props.filetype ~= next_props.filetype then return true end
  -- Skip update if nothing changed
  return false
end

function SplitDiffComponent:component_did_mount()
  self:render()
end

function SplitDiffComponent:component_did_update(prev_state)
  self:render()
end

function SplitDiffComponent:component_will_mount()
  local child_win_options = {
    scrollbind = true,
    cursorbind = true,
  }

  if self.props.win_options then
    child_win_options = vim.tbl_deep_extend('force', child_win_options, self.props.win_options)
  end

  local previous_plot = nil
  local current_plot = nil

  local window_mode = self.config and self.config.window_mode or 'popup'

  if window_mode == 'screen' then
  elseif window_mode == 'lens' or window_mode == 'popup' then
    local width = vim.o.columns
    local height = '35vh'

    if self.props.layout_config then height = self.props.layout_config.height or '35vh' end
    height = LayoutContext.convert_dimension(height) or height

    local half_width = math.floor(width / 2)
    local zindex = (self.props.layout_config and self.props.layout_config.zindex) or 2

    previous_plot = {
      win_plot = {
        relative = 'cursor',
        row = 1,
        col = 0,
        width = half_width,
        height = height,
        style = 'minimal',
        focusable = true,
        zindex = zindex,
      },
    }

    current_plot = {
      win_plot = {
        relative = 'cursor',
        row = 1,
        col = half_width,
        width = half_width,
        height = height,
        style = 'minimal',
        focusable = true,
        focus = true,
        zindex = zindex,
      },
    }
  end

  if not self._previous_component then
    self._previous_component = DiffComponent({
      filetype = self.props.filetype or 'diff',
      win_options = child_win_options,
      plot = previous_plot,
    })
    self._previous_component:mount()
  end

  if not self._current_component then
    self._current_component = DiffComponent({
      filetype = self.props.filetype or 'diff',
      win_options = child_win_options,
      plot = current_plot,
    })
    self._current_component:mount()
  end
end

function SplitDiffComponent:component_will_unmount()
  self:_for_both(function(c) c:unmount() end)
end

function SplitDiffComponent:render()
  local diff = self.props.diff

  if not diff then
    self.state.previous_lines = {}
    self.state.current_lines = {}
    self:clear_lines()
    self:reset_cursor()
    return
  end

  local result = self:calculate_split_line_numbers(diff)

  local previous_diff = vim.tbl_extend('force', diff, {
    lines = diff.previous_lines or {},
  })

  local current_diff = vim.tbl_extend('force', diff, {
    lines = diff.current_lines or {},
  })

  if self._previous_component then
    self._previous_component:set_props({
      diff = previous_diff,
      filetype = self.props.filetype,
      _split_line_numbers = result.previous.lines,
      _split_lines_changes = result.previous.changes,
    })
  end
  if self._current_component then
    self._current_component:set_props({
      diff = current_diff,
      filetype = self.props.filetype,
      _split_line_numbers = result.current.lines,
      _split_lines_changes = result.current.changes,
    })
  end

  self.state.previous_lines = diff.previous_lines or {}
  self.state.current_lines = diff.current_lines or {}
end

function SplitDiffComponent:get_layout_spec()
  return LayoutSpec.horizontal({
    LayoutSpec.view(self._previous_component, { flex = 1 }),
    LayoutSpec.view(self._current_component, { flex = 1 }),
  })
end

function SplitDiffComponent:get_component(id)
  if id == 'current' then
    return self._current_component
  elseif id == 'previous' then
    return self._previous_component
  end
  return nil
end

function SplitDiffComponent:set_lines(previous_lines, current_lines)
  self:set_state({
    previous_lines = previous_lines or {},
    current_lines = current_lines or {},
  })
  if self.mounted then self:render() end
  return self
end

function SplitDiffComponent:clear_lines()
  self:_for_both(function(c) c:clear_lines():disable_cursorline() end)
  self:set_state({ previous_lines = {}, current_lines = {} })
end

function SplitDiffComponent:set_lnum(lnum, position)
  self:_for_both(function(c)
    c:set_lnum(lnum)
    if position then c:position_cursor(position) end
  end)
end

function SplitDiffComponent:get_lnum()
  if self._current_component then return self._current_component:get_lnum() end
  return 1
end

function SplitDiffComponent:reset_cursor()
  self:_for_both(function(c) c:reset_cursor() end)
end

function SplitDiffComponent:enable_cursorline()
  self:_for_both(function(c) c:enable_cursorline() end)
end

function SplitDiffComponent:disable_cursorline()
  self:_for_both(function(c) c:disable_cursorline() end)
end

function SplitDiffComponent:set_filetype(filetype)
  self:_for_both(function(c) c:set_filetype(filetype) end)
end

function SplitDiffComponent:get_filetype()
  if self._current_component then return self._current_component:get_filetype() end
  return ''
end

function SplitDiffComponent:clear_extmarks()
  self:_for_both(function(c) c:clear_extmarks() end)
end

function SplitDiffComponent:attach_to_renderer(callback)
  self:_for_both(function(c) c:attach_to_renderer(callback) end)
end

function SplitDiffComponent:is_valid()
  return (self._previous_component and self._previous_component:is_valid())
    or (self._current_component and self._current_component:is_valid())
end

function SplitDiffComponent:hunk_down(pos)
  if self._current_component then return self._current_component:hunk_down(pos) end
  return nil
end

function SplitDiffComponent:hunk_up(pos)
  if self._current_component then return self._current_component:hunk_up(pos) end
  return nil
end

function SplitDiffComponent:move_to_hunk(mark_index, pos)
  if not self._current_component then return nil end

  local mark = self._current_component:move_to_hunk(mark_index, pos)

  if mark and self._previous_component then
    self._previous_component:set_lnum(mark.top)
    if pos then self._previous_component:position_cursor(pos) end
  end

  return mark
end

function SplitDiffComponent:get_hunk_under_cursor()
  if self._current_component then return self._current_component:get_hunk_under_cursor() end
  return nil
end

function SplitDiffComponent:get_current_mark_under_cursor()
  if self._current_component then return self._current_component:get_current_mark_under_cursor() end
  return nil
end

function SplitDiffComponent:get_relative_mark_index(lnum)
  if self._current_component then return self._current_component:get_relative_mark_index(lnum) end
  return 1
end

function SplitDiffComponent:get_marks()
  if self._current_component then return self._current_component:get_marks() end
  return {}
end

function SplitDiffComponent:get_hunks()
  if self._current_component then return self._current_component:get_hunks() end
  return {}
end

function SplitDiffComponent:render_folds()
  self:_for_both(function(c) c:render_folds() end)
end

function SplitDiffComponent:clear_folds()
  self:_for_both(function(c) c:clear_folds() end)
end

function SplitDiffComponent:call(callback)
  if self._current_component and self._current_component:is_valid() and callback then
    self._current_component:call(callback)
  end
end

function SplitDiffComponent:on(event_name, callback)
  self:_for_both(function(c) c:on(event_name, callback) end)
end

function SplitDiffComponent:set_keymap(mode_or_opts, key_or_callback, handler, desc)
  self:_for_both(function(c) c:set_keymap(mode_or_opts, key_or_callback, handler, desc) end)
end

function SplitDiffComponent:unmount()
  self:_for_both(function(c) c:unmount() end)
end

return SplitDiffComponent
