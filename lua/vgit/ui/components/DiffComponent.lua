local lazy = require('vgit.core.lazy')

local symbols_setting = lazy('vgit.settings.symbols')
local DiffAnnotator = lazy('vgit.ui.annotators.DiffAnnotator')
local FoldCalculator = lazy('vgit.ui.calculators.FoldCalculator')
local LineNumberCalculator = lazy('vgit.ui.calculators.LineNumberCalculator')
local DiffViewportComponent = lazy('vgit.ui.DiffViewportComponent')

local DiffComponent = DiffViewportComponent:extend()

function DiffComponent:constructor(props)
  local instance = DiffViewportComponent.constructor(self, props)
  instance._line_number_calculator = LineNumberCalculator()
  instance._diff_annotator = DiffAnnotator()
  instance._fold_calculator = FoldCalculator()
  return instance
end

function DiffComponent:get_buf_options()
  return {
    modifiable = false,
    buflisted = false,
    bufhidden = 'wipe',
    filetype = 'diff',
  }
end

function DiffComponent:get_win_options()
  return {
    winhl = 'Normal:GitBackground',
    signcolumn = 'auto',
    wrap = false,
    number = false,
    cursorline = true,
    foldmethod = 'manual',
    foldenable = true,
    foldlevel = 0,
  }
end

function DiffComponent:get_layout_opts()
  return { id = 'body', flex = 1, focus = true }
end

function DiffComponent:on_props(prev_props)
  if self.props.diff ~= prev_props.diff or self.props.filetype ~= prev_props.filetype then self:render() end
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

function DiffComponent:calculate_folds(diff, line_count)
  return self._fold_calculator:calculate_folds(diff.marks or {}, line_count)
end

function DiffComponent:calculate_unified_line_numbers(diff)
  return self._line_number_calculator:calculate_unified_line_numbers(diff)
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
  self:render_folds()
end

function DiffComponent:set_lines(lines)
  self:set_state({ lines = lines })
  return self
end

function DiffComponent:clear_lines()
  self:with_element(function(el)
    el:clear_extmarks()
    el:clear_lines()
  end)
  self.state.lines = {}
  return self
end

function DiffComponent:render_viewport(top, bot)
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
        if line_marks.sign then
          el:place_extmark_sign({
            row = line_marks.sign.row,
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
      self:render_viewport(top, bot + 1)
    end)
  end)
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

function DiffComponent:reset()
  DiffViewportComponent.reset(self)
  self:clear_folds()
  return self
end

return DiffComponent
