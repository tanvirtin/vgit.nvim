local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local symbols_setting = lazy('vgit.settings.symbols')
local ViewportComponent = lazy('vgit.ui.ViewportComponent')
local DiffAnnotator = lazy('vgit.ui.annotators.DiffAnnotator')
local FoldCalculator = lazy('vgit.ui.calculators.FoldCalculator')
local LineNumberCalculator = lazy('vgit.ui.calculators.LineNumberCalculator')

local DiffComponent = ViewportComponent:extend()

function DiffComponent:constructor(props)
  local instance = ViewportComponent.constructor(self, props)
  instance._element = nil
  instance._line_number_calculator = LineNumberCalculator()
  instance._diff_annotator = DiffAnnotator()
  instance._fold_calculator = FoldCalculator()
  return instance
end

function DiffComponent:calculate_folds(diff, line_count)
  return self._fold_calculator:calculate_folds(diff.marks or {}, line_count)
end

function DiffComponent:calculate_unified_line_numbers(diff)
  return self._line_number_calculator:calculate_unified_line_numbers(diff)
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

function DiffComponent:build_diff_render_state(diff)
  if not diff then return { lines = {}, line_numbers = {}, lines_changes = {}, folds = {}, marks = {}, hunks = {} } end

  local line_numbers = self.props._split_line_numbers
  local lines_changes = self.props._split_lines_changes

  if not line_numbers then
    line_numbers, lines_changes = self:calculate_unified_line_numbers(diff)
  end

  -- Pre-pad line number text so the viewport renderer just reads them
  if #line_numbers > 0 then
    local max_digits = string.len(tostring(#line_numbers)) + 1
    local pad_fmt = '%' .. max_digits .. 's'
    for i = 1, #line_numbers do
      local ln = line_numbers[i]
      if ln then ln[1] = string.format(pad_fmt, ln[1]) end
    end
  end

  local line_count = #diff.lines
  return {
    lines = diff.lines,
    marks = diff.marks or {},
    hunks = diff.hunks or {},
    line_numbers = line_numbers,
    lines_changes = lines_changes,
    folds = line_count > 0 and self:calculate_folds(diff, line_count) or {},
  }
end

function DiffComponent:render()
  local diff = self.props.diff

  self:mark_viewport_dirty()

  -- Only clear signs; line numbers and text extmarks use stable IDs
  -- and get overwritten in-place by the viewport renderer
  self:with_element(function(el)
    el:clear_extmark_signs()
  end)

  local new_state = self:build_diff_render_state(diff)
  self.state.lines = new_state.lines
  self.state.marks = new_state.marks
  self.state.hunks = new_state.hunks
  self.state.line_numbers = new_state.line_numbers
  self.state.lines_changes = new_state.lines_changes
  self.state.folds = new_state.folds

  if not diff then
    self:clear_lines()
    self:reset_cursor()
    return
  end

  if self.props.filetype then self:set_filetype(self.props.filetype) end

  self:with_element(function(el)
    el:set_lines(diff.lines)
    el:enable_cursorline()
  end)

  -- Attach once — the callback reads from self.state which we just updated
  self:_ensure_renderer_attached()
end

function DiffComponent:get_layout_spec()
  return LayoutSpec.view(self._element, { id = 'body', flex = 1, focus = true })
end

function DiffComponent:set_lines(lines)
  self:set_state({ lines = lines })
  if self._mounted then self:render() end
  return self
end

function DiffComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end) or self.state.lines
end

function DiffComponent:clear_lines()
  self:with_element(function(el)
    el:clear_lines()
  end)
  self:set_state({ lines = {} })
  return self
end

function DiffComponent:set_cursor(cursor)
  self:with_element(function(el)
    el:set_cursor(cursor)
  end)
  return self
end

function DiffComponent:get_cursor()
  return self:with_element(function(el)
    return el:get_cursor()
  end) or { 1, 1 }
end

function DiffComponent:set_lnum(lnum)
  self:with_element(function(el)
    el:set_lnum(lnum)
  end)
  return self
end

function DiffComponent:get_lnum()
  return self:with_element(function(el)
    return el:get_lnum()
  end) or 1
end

function DiffComponent:reset_cursor()
  return self:set_cursor({ 1, 0 })
end

function DiffComponent:scroll_to(placement, offset)
  self:with_element(function(el)
    el:scroll_to(placement, offset)
  end)
  return self
end

function DiffComponent:call(callback)
  if callback then self:with_element(function(el)
    el:call(callback)
  end) end
  return self
end

function DiffComponent:enable_cursorline()
  self:with_element(function(el)
    el:enable_cursorline()
  end)
  return self
end

function DiffComponent:disable_cursorline()
  self:with_element(function(el)
    el:disable_cursorline()
  end)
  return self
end

function DiffComponent:get_line_count()
  return self:with_element(function(el)
    return el:get_line_count()
  end) or 0
end

function DiffComponent:get_filetype()
  return self:with_element(function(el)
    return el:get_filetype()
  end) or ''
end

function DiffComponent:clear_extmarks()
  self:with_element(function(el)
    el:clear_extmarks()
  end)
  return self
end

function DiffComponent:set_keymap(config, handler)
  self:with_element(function(el)
    el:set_keymap(config, handler)
  end)
  return self
end

function DiffComponent:attach_to_renderer(callback)
  self:with_element(function(el)
    el:attach_to_renderer(callback)
  end)
  return self
end

function DiffComponent:is_valid()
  return self:with_element(function()
    return true
  end) or false
end

Component.forward(DiffComponent, function(self)
  return self._element and self._element:is_valid() and self._element
end, {
  'place_extmark_text',
  'place_extmark_sign',
  'place_extmark_lnum',
  'place_extmark_highlight',
  'set_filetype',
})

function DiffComponent:find_adjacent_mark_index(direction)
  local marks = self.state.marks
  if #marks == 0 then return nil end

  local lnum = self:get_lnum()

  if direction == 'next' then
    for i = 1, #marks do
      local mark = marks[i]
      if lnum >= mark.top and lnum <= mark.bot then return i + 1 end
      if mark.top > lnum then return i end
    end
    return 1
  end

  for i = #marks, 1, -1 do
    local mark = marks[i]
    if lnum >= mark.top and lnum <= mark.bot then return i - 1 end
    if mark.top < lnum then return i end
  end
  return #marks
end

function DiffComponent:hunk_down(pos, offset)
  local mark_index = self:find_adjacent_mark_index('next')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

function DiffComponent:hunk_up(pos, offset)
  local mark_index = self:find_adjacent_mark_index('prev')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

function DiffComponent:move_to_hunk(mark_index, pos, offset)
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
  if not mark then return nil end

  self:set_lnum(mark.top)
  if pos then self:scroll_to(pos, offset) end
  return mark
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

function DiffComponent:get_hunks()
  return self.state.hunks or {}
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

function DiffComponent:render_diff(top, bot)
  top = top or 1
  bot = bot or #self.state.lines_changes

  if self:is_viewport_unchanged(top, bot) then return end

  -- Single with_element call for entire viewport — avoids per-line validity checks
  local rendered = self:with_element(function(el)
    local lines_changes = self.state.lines_changes
    local line_numbers = self.state.line_numbers

    -- Render pre-padded line numbers for visible range
    if line_numbers and #line_numbers > 0 then
      for i = top, math.min(bot, #line_numbers) do
        local ln = line_numbers[i]
        if ln then
          el:place_extmark_lnum({
            row = i - 1,
            hl = ln[2],
            text = ln[1],
          })
        end
      end
    end

    -- Hoist void text computation — same for all void lines in this viewport
    local void_text

    -- Render diff marks for visible range
    for lnum = top, bot do
      if lines_changes and lines_changes[lnum] then
        local line_changes = lines_changes[lnum]

        local line_marks = self._diff_annotator:annotate_line(line_changes)
        if line_marks then
          if line_marks.sign then
            el:place_extmark_sign({
              col = line_marks.sign.col,
              name = line_marks.sign.name,
            })
          end

          if line_marks.void_text then
            if not void_text then void_text = string.rep(symbols_setting:get('void'), el:get_width()) end
            el:place_extmark_text({
              row = line_marks.void_text.row,
              col = line_marks.void_text.col,
              text = void_text,
              hl = line_marks.void_text.hl,
            })
          end
        end

        local word_marks = self._diff_annotator:annotate_word(line_changes, lnum)
        if word_marks then
          el:place_extmark_text({
            row = word_marks.row,
            col = word_marks.col,
            texts = word_marks.texts,
          })
        end
      end
    end

    return true
  end)

  if rendered then self:commit_viewport(top, bot) end
end

function DiffComponent:_ensure_renderer_attached()
  self:ensure_renderer_attached(function()
    self:attach_to_renderer(function(top, bot)
      self:render_diff(top, bot + 1)
    end)
  end)
end

function DiffComponent:render_diff_partially()
  self:_ensure_renderer_attached()
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
  self:with_element(function(el)
    el:sync_win_options()
  end)
  return self
end

function DiffComponent:unmount()
  if not self._mounted then return end

  self._element:unmount()
  self._element = nil

  ViewportComponent.unmount(self)
end

return DiffComponent
