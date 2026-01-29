local Component = require('vgit.ui.Component')
local Element = require('vgit.ui.elements.Element')
local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
local DiffCalculator = require('vgit.ui.calculators.DiffCalculator')
local FoldCalculator = require('vgit.ui.calculators.FoldCalculator')
local LineNumberCalculator = require('vgit.ui.calculators.LineNumberCalculator')

local DiffComponent = Component:extend()

function DiffComponent:constructor(props)
  local instance = Component.constructor(self, props)
  instance._element = nil
  instance._line_number_calculator = LineNumberCalculator()
  instance._diff_calculator = DiffCalculator()
  instance._fold_calculator = FoldCalculator()
  return instance
end

function DiffComponent:calculate_line_diff_marks(line_changes)
  return self._diff_calculator:calculate_line_diff_marks(line_changes)
end

function DiffComponent:calculate_folds(diff, line_count)
  return self._fold_calculator:calculate_folds(diff.marks or {}, line_count)
end

function DiffComponent:calculate_unified_line_numbers(diff)
  return self._line_number_calculator:calculate_unified_line_numbers(diff)
end

function DiffComponent:calculate_word_diff_marks(line_changes, lnum)
  return self._diff_calculator:calculate_word_diff_marks(line_changes, lnum)
end

function DiffComponent:get_initial_state()
  return {
    lines = {},
    line_numbers = {},
    lines_changes = {},
    folds = {},
    marks = {},
    hunks = {},
  }
end

function DiffComponent:should_component_update(next_props, next_state)
  if self.props.diff ~= next_props.diff then return true end
  if self.props.filetype ~= next_props.filetype then return true end
  return false
end

function DiffComponent:component_did_mount()
  self:render()
end

function DiffComponent:component_did_update(prev_state)
  self:render()
end

function DiffComponent:component_will_mount()
  if not self._element then
    local utils = require('vgit.core.utils')

    local default_win_options = {
      winhl = 'Normal:GitBackground',
      signcolumn = 'auto',
      wrap = false,
      number = false,
      cursorline = true,
    }

    local win_options = utils.object.assign(default_win_options, self.props.win_options or {})

    local element_config = {
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
        filetype = self.props.filetype or 'diff',
      },
      win_options = win_options,
    }

    if self.props.plot then element_config.plot = self.props.plot end

    self._element = Element(element_config)
  end
end

function DiffComponent:render()
  local diff = self.props.diff

  self:clear_extmarks()

  if not diff then
    self.state.lines = {}
    self.state.line_numbers = {}
    self.state.lines_changes = {}
    self.state.folds = {}
    self.state.marks = {}
    self.state.hunks = {}
    self:clear_lines()
    self:reset_cursor()
    return
  end

  self.state.marks = diff.marks or {}
  self.state.hunks = diff.hunks or {}

  if self.props.filetype then self:set_filetype(self.props.filetype) end

  if self._element and self._element:is_valid() then
    self._element:set_lines(diff.lines)
    self._element:enable_cursorline()
  end

  self.state.lines = diff.lines

  if self._element and self._element:is_valid() then
    local buffer_line_count = self._element:get_line_count()
    if buffer_line_count > 0 then
      local line_numbers = self.props._split_line_numbers
      local lines_changes = self.props._split_lines_changes

      if not line_numbers then
        line_numbers, lines_changes = self:calculate_unified_line_numbers(diff)
      end

      self.state.line_numbers = line_numbers
      self.state.lines_changes = lines_changes

      self.state.folds = self:calculate_folds(diff, buffer_line_count)

      self:render_line_numbers(line_numbers)
    end
  end

  self:render_diff_partially()
end

function DiffComponent:get_layout_spec()
  if #self.state.lines > 0 then self._element._lines = self.state.lines end

  return LayoutSpec.view(self._element, { id = 'body', flex = 1, focus = true })
end

function DiffComponent:set_lines(lines)
  self:set_state({ lines = lines })
  if self.mounted then self:render() end
  return self
end

function DiffComponent:get_lines()
  if self._element and self._element:is_valid() then return self._element:get_lines() end
  return self.state.lines
end

function DiffComponent:clear_lines()
  if self._element and self._element:is_valid() then self._element:clear_lines() end
  self:set_state({ lines = {} })
  return self
end

function DiffComponent:render_line_numbers(lines)
  if not self._element or not self._element:is_valid() then return self end

  local offset = 1
  local max_digits = string.len(tostring(#lines)) + offset

  for i = 1, #lines do
    local hl = lines[i][2]
    local text = lines[i][1]
    local text_len = string.len(text)
    if text_len < max_digits then text = string.format('%s%s', string.rep(' ', max_digits - text_len), text) end
    self._element:place_extmark_lnum({
      row = i - 1,
      hl = hl,
      text = text,
    })
  end

  return self
end

function DiffComponent:set_cursor(cursor)
  if self._element and self._element:is_valid() then self._element:set_cursor(cursor) end
  return self
end

function DiffComponent:get_cursor()
  if self._element and self._element:is_valid() then return self._element:get_cursor() end
  return { 1, 1 }
end

function DiffComponent:set_lnum(lnum)
  if self._element and self._element:is_valid() then self._element:set_lnum(lnum) end
  return self
end

function DiffComponent:get_lnum()
  if self._element and self._element:is_valid() then return self._element:get_lnum() end
  return 1
end

function DiffComponent:reset_cursor()
  return self:set_cursor({ 1, 0 })
end

function DiffComponent:position_cursor(placement)
  if not self._element or not self._element:is_valid() then return self end
  self._element:position_cursor(placement)
  return self
end

function DiffComponent:call(callback)
  if self._element and self._element:is_valid() and callback then self._element:call(callback) end
  return self
end

function DiffComponent:enable_cursorline()
  if self._element and self._element:is_valid() then self._element:enable_cursorline() end
  return self
end

function DiffComponent:disable_cursorline()
  if self._element and self._element:is_valid() then self._element:disable_cursorline() end
  return self
end

function DiffComponent:get_line_count()
  if self._element and self._element:is_valid() then return self._element:get_line_count() end
  return 0
end

function DiffComponent:set_filetype(filetype)
  if self._element and self._element:is_valid() then self._element:set_filetype(filetype) end
end

function DiffComponent:get_filetype()
  if self._element and self._element:is_valid() then return self._element:get_filetype() end
  return ''
end

function DiffComponent:place_extmark_text(opts)
  if self._element and self._element:is_valid() then return self._element:place_extmark_text(opts) end
  return nil
end

function DiffComponent:place_extmark_sign(opts)
  if self._element and self._element:is_valid() then return self._element:place_extmark_sign(opts) end
  return nil
end

function DiffComponent:place_extmark_lnum(opts)
  if self._element and self._element:is_valid() then return self._element:place_extmark_lnum(opts) end
  return nil
end

function DiffComponent:place_extmark_highlight(opts)
  if self._element and self._element:is_valid() then return self._element:place_extmark_highlight(opts) end
  return nil
end

function DiffComponent:clear_extmarks()
  if self._element and self._element:is_valid() then self._element:clear_extmarks() end
  return self
end

function DiffComponent:set_keymap(config, handler)
  if self._element and self._element:is_valid() then self._element:set_keymap(config, handler) end
  return self
end

function DiffComponent:attach_to_renderer(callback)
  if self._element and self._element:is_valid() then self._element:attach_to_renderer(callback) end
  return self
end

function DiffComponent:is_valid()
  return self._element and self._element:is_valid()
end

function DiffComponent:hunk_down(pos)
  local marks = self.state.marks
  if #marks == 0 then return nil end

  local lnum = self:get_lnum()
  local mark_index = 1
  local num_marks = #marks

  for i = 1, num_marks do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then
      mark_index = i + 1
      break
    elseif mark.top > lnum then
      mark_index = i
      break
    end
  end

  local result = self:move_to_hunk(mark_index, pos)
  if result then
    if mark_index < 1 then
      mark_index = #marks
    elseif mark_index > #marks then
      mark_index = 1
    end
  end

  return result
end

function DiffComponent:hunk_up(pos)
  local marks = self.state.marks
  if #marks == 0 then return nil end

  local lnum = self:get_lnum()
  local mark_index = #marks

  for i = #marks, 1, -1 do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then
      mark_index = i - 1
      break
    elseif mark.top < lnum then
      mark_index = i
      break
    end
  end

  local result = self:move_to_hunk(mark_index, pos)
  if result then
    if mark_index < 1 then
      mark_index = #marks
    elseif mark_index > #marks then
      mark_index = 1
    end
  end

  return result
end

function DiffComponent:move_to_hunk(mark_index, pos)
  pos = pos or 'center'
  mark_index = mark_index or 1

  local marks = self.state.marks
  if #marks == 0 then return nil end

  if mark_index < 1 then
    mark_index = #marks
  elseif mark_index > #marks then
    mark_index = 1
  end

  local mark = marks[mark_index]
  if mark then
    self:set_lnum(mark.top)
    if pos then self:position_cursor(pos) end
    return mark
  end

  return nil
end

function DiffComponent:get_hunk_under_cursor()
  local marks = self.state.marks
  local hunks = self.state.hunks
  if #marks == 0 or #hunks == 0 then return nil end

  local lnum = self:get_lnum()

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then return hunks[i], i end
  end

  return nil
end

function DiffComponent:get_current_mark_under_cursor()
  local marks = self.state.marks
  if #marks == 0 then return nil end

  local lnum = self:get_lnum()

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then return mark, i end
  end

  return nil
end

function DiffComponent:get_marks()
  return self.state.marks or {}
end

function DiffComponent:get_relative_mark_index(lnum)
  local marks = self.state.marks
  if #marks == 0 then return 1 end

  for i = 1, #marks do
    local mark = marks[i]
    if lnum >= mark.top_relative and lnum <= mark.bot_relative then return i end
  end

  return 1
end

function DiffComponent:render_word_diff(line_changes, lnum)
  if not self._element or not self._element:is_valid() then return end

  local marks = self:calculate_word_diff_marks(line_changes, lnum)
  if not marks then return end

  self._element:place_extmark_text({
    row = marks.row,
    col = marks.col,
    texts = marks.texts,
  })
end

function DiffComponent:render_line_diff(line_changes)
  if not self._element or not self._element:is_valid() then return end

  local marks = self:calculate_line_diff_marks(line_changes)
  if not marks then return end

  if marks.sign then self._element:place_extmark_sign({
    col = marks.sign.col,
    name = marks.sign.name,
  }) end

  if marks.void_text then
    local symbols_setting = require('vgit.settings.symbols')
    local width = self._element:get_width()
    local text = string.rep(symbols_setting:get('void'), width)
    self._element:place_extmark_text({
      row = marks.void_text.row,
      col = marks.void_text.col,
      text = text,
      hl = marks.void_text.hl,
    })
  end
end

function DiffComponent:render_diff(top, bot)
  top = top or 1
  bot = bot or #self.state.lines_changes

  local lines_changes = self.state.lines_changes

  for lnum = top, bot do
    if lines_changes and lines_changes[lnum] then
      local line_changes = lines_changes[lnum]
      self:render_line_diff(line_changes)
      self:render_word_diff(line_changes, lnum)
    end
  end
end

function DiffComponent:render_diff_partially()
  self:attach_to_renderer(function(top, bot)
    self:render_diff(top, bot + 1)
  end)
  return self
end

function DiffComponent:render_folds()
  local folds = self.state.folds
  if #folds == 0 then return self end
  self._fold_calculator:apply_folds(self, folds)
  return self
end

function DiffComponent:clear_folds()
  self._fold_calculator:clear_folds(self)
  return self
end

function DiffComponent:ensure_window_options()
  if self._element and self._element:is_valid() then self._element:reapply_window_options() end
  return self
end

function DiffComponent:unmount()
  if not self.mounted then return end

  self._element:unmount()
  self._element = nil

  Component.unmount(self)
end

return DiffComponent
