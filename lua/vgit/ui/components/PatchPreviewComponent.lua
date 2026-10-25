local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local patch = lazy('vgit.core.patch')
local symbols_setting = lazy('vgit.settings.symbols')
local DiffAnnotator = lazy('vgit.ui.annotators.DiffAnnotator')
local DiffStyleAnnotator = lazy('vgit.ui.annotators.DiffStyleAnnotator')
local SyntaxMappingAnnotator = lazy('vgit.ui.annotators.SyntaxMappingAnnotator')
local DiffViewportComponent = lazy('vgit.ui.DiffViewportComponent')
local PatchLineBuilder = lazy('vgit.core.patch.PatchLineBuilder')

local PatchPreviewComponent = DiffViewportComponent:extend()

function PatchPreviewComponent:constructor(props)
  local instance = DiffViewportComponent.constructor(self, props)
  instance._syntax_mapping_annotator = SyntaxMappingAnnotator()
  instance._render_gen = 0
  instance._syntax_pending = false
  return instance
end

function PatchPreviewComponent:get_buf_options()
  return {
    modifiable = false,
    buflisted = false,
    bufhidden = 'wipe',
    filetype = 'diff',
  }
end

function PatchPreviewComponent:get_win_options()
  return {
    winhl = 'Normal:GitBackground',
    signcolumn = 'no',
    wrap = false,
    number = false,
    cursorline = true,
  }
end

function PatchPreviewComponent:get_layout_opts()
  return {
    id = self.props.id or 'patch_preview',
    flex = self.props.flex or 1,
    focus = self.props.focus or false,
  }
end

function PatchPreviewComponent:on_props(prev_props)
  if self.props.hunk_entries ~= prev_props.hunk_entries then self:render() end
end

function PatchPreviewComponent:get_initial_state()
  return {
    lines = {},
    line_metadata = {},
    marks = {},
    _diff_hl_map = {},
    _syntax_hl_map = {},
    _syntax_sections = {},
    _line_numbers = {},
    _raw_lnums = {},
    _max_lnum = 0,
  }
end

function PatchPreviewComponent:on_unmount()
  if self._syntax_mapping_annotator then self._syntax_mapping_annotator:dispose() end
end

function PatchPreviewComponent:render()
  self:mark_viewport_dirty()
  self._render_gen = self._render_gen + 1

  self:with_element(function(el)
    el:clear_extmark_highlights()
  end)

  local hunk_entries = self.props.hunk_entries

  if not hunk_entries or #hunk_entries == 0 then
    self.state.lines = {}
    self.state.line_metadata = {}
    self.state.marks = {}
    self.state._diff_hl_map = {}
    self.state._syntax_hl_map = {}
    self.state._syntax_sections = {}
    self.state._line_numbers = {}
    self.state._raw_lnums = {}
    self.state._max_lnum = 0
    self:clear_lines()
    self:reset_cursor()
    return
  end

  local layout = patch.build(hunk_entries, { style = DiffStyleAnnotator.annotate })
  local lines = layout.lines
  self.state.lines = lines
  self.state.line_metadata = layout.line_metadata
  self.state.marks = layout.marks or {}
  self.state._line_numbers = layout.line_numbers or {}
  self.state._raw_lnums = layout.raw_lnums or {}
  self.state._max_lnum = layout.max_lnum or 0

  if #lines == 0 then
    self:clear_lines()
    self:reset_cursor()
    return
  end

  self:with_element(function(el)
    el:set_lines(lines)
    el:enable_cursorline()
  end)

  self.state._diff_hl_map = self:_build_highlight_map(layout.highlights)

  self.state._syntax_hl_map = {}
  self.state._syntax_sections = layout.file_sections

  self:_ensure_renderer_attached()
end

function PatchPreviewComponent:append_hunk_entries(hunk_entries)
  if not hunk_entries or #hunk_entries == 0 then return end

  local state = self.state
  if #state.lines == 0 then
    local all_entries = vim.list_extend(vim.list_extend({}, self.props.hunk_entries or {}), hunk_entries)
    self:set_props({ hunk_entries = all_entries })
    return
  end

  local layout = patch.build(hunk_entries, { style = DiffStyleAnnotator.annotate })
  local lines = layout.lines
  if #lines == 0 then return end

  vim.list_extend(self.props.hunk_entries, hunk_entries)

  local blank_row = #state.lines
  local row_offset = blank_row + 1

  state.lines[blank_row + 1] = ''
  state.line_metadata[blank_row + 1] = { type = 'blank' }
  state._raw_lnums[blank_row + 1] = { lnum = nil, hl = 'GitLineNr' }
  for i, line in ipairs(lines) do
    state.lines[row_offset + i] = line
    state.line_metadata[row_offset + i] = layout.line_metadata[i]
    state._raw_lnums[row_offset + i] = layout.raw_lnums[i]
  end

  for _, mark in ipairs(layout.marks) do
    state.marks[#state.marks + 1] = { top = mark.top + row_offset, bot = mark.bot + row_offset }
  end

  for _, section in ipairs(layout.file_sections) do
    section.start_row = section.start_row + row_offset
    section.end_row = section.end_row + row_offset
    for _, mapping in ipairs(section.syntax_mappings) do
      mapping.display_row = mapping.display_row + row_offset
    end
    state._syntax_sections[#state._syntax_sections + 1] = section
  end

  local diff_hl_map = state._diff_hl_map
  for _, hl in ipairs(layout.highlights) do
    hl.row = hl.row + row_offset
    local row_hls = diff_hl_map[hl.row]
    if not row_hls then
      row_hls = {}
      diff_hl_map[hl.row] = row_hls
    end
    row_hls[#row_hls + 1] = hl
  end

  local previous_width = PatchLineBuilder.lnum_width(state._max_lnum)
  state._max_lnum = math.max(state._max_lnum, layout.max_lnum)
  if PatchLineBuilder.lnum_width(state._max_lnum) ~= previous_width then
    state._line_numbers = PatchLineBuilder.format_line_numbers(state._raw_lnums, state._max_lnum)
  else
    local appended = PatchLineBuilder.format_line_numbers(
      vim.list_slice(state._raw_lnums, blank_row + 1, #state._raw_lnums),
      state._max_lnum
    )
    for i, line_number in ipairs(appended) do
      state._line_numbers[blank_row + i] = line_number
    end
  end

  table.insert(lines, 1, '')
  self:with_element(function(el)
    el:set_lines(lines, blank_row, blank_row)
  end)
  self:mark_viewport_dirty()
end

function PatchPreviewComponent:_unresolved_sections(top, bot)
  local unresolved = {}
  for _, section in ipairs(self.state._syntax_sections or {}) do
    if section.start_row > bot then break end
    if not section.syntax_resolved and section.end_row >= top then unresolved[#unresolved + 1] = section end
  end
  return unresolved
end

function PatchPreviewComponent:_schedule_syntax(top, bot)
  if self._syntax_pending or #self:_unresolved_sections(top, bot) == 0 then return end

  self._syntax_pending = true
  local gen = self._render_gen
  event.async(function()
    event.await()
    self._syntax_pending = false
    if not self._mounted or self._render_gen ~= gen then return end

    top = self._last_top or top
    bot = self._last_bot or bot
    local highlights = {}
    for _, section in ipairs(self:_unresolved_sections(top, bot)) do
      self:_resolve_section_syntax(highlights, section)
      section.syntax_resolved = true
    end

    local syntax_hl_map = self.state._syntax_hl_map
    for row, hls in pairs(self:_build_highlight_map(highlights)) do
      syntax_hl_map[row] = hls
    end
    self:mark_viewport_dirty()
    self:render_viewport(top, bot)
  end)()
end

function PatchPreviewComponent:_resolve_section_syntax(result, section)
  local filetype = section.filetype
  local syntax_mappings = section.syntax_mappings

  if not filetype or filetype == '' or filetype == 'text' then return end
  if not syntax_mappings or #syntax_mappings == 0 then return end

  local highlights = self._syntax_mapping_annotator:annotate({
    original_lines = section.original_lines,
    current_lines = section.current_lines,
    filetype = filetype,
    syntax_mappings = syntax_mappings,
  })

  for _, hl in ipairs(highlights) do
    result[#result + 1] = hl
  end
end

function PatchPreviewComponent:_build_highlight_map(highlights)
  local map = {}
  for _, hl in ipairs(highlights) do
    local row = hl.row
    if not map[row] then map[row] = {} end
    map[row][#map[row] + 1] = hl
  end
  return map
end

function PatchPreviewComponent:render_viewport(top, bot)
  if self:is_viewport_unchanged(top, bot) then return end

  local rendered = self:with_element(function(el)
    el:clear_extmark_highlights(top, bot)

    local diff_hl_map = self.state._diff_hl_map
    local syntax_hl_map = self.state._syntax_hl_map
    local line_numbers = self.state._line_numbers
    local line_metadata = self.state.line_metadata
    local void_text

    for row = top, bot do
      local ln = line_numbers[row + 1]
      if ln then el:place_extmark_lnum({
        row = row,
        hl = ln.hl,
        text = ln.text,
      }) end

      local meta = line_metadata[row + 1]
      if meta and meta.lnum_change and meta.lnum_change.type == 'void' then
        if not void_text then void_text = string.rep(symbols_setting:get('void'), el:get_width()) end
        el:place_extmark_text({
          row = row,
          col = 0,
          text = void_text,
          hl = 'GitLineNr',
        })
      end

      local overlay = DiffAnnotator.word_overlay_for(meta and meta.lnum_change, self.state.lines[row + 1])
      if overlay then el:place_extmark_text({ row = row, col = overlay.col, texts = overlay.texts }) end

      local diff_hls = diff_hl_map[row]
      if diff_hls then
        for _, hl in ipairs(diff_hls) do
          if hl.line then
            el:place_extmark_highlight({
              hl = hl.hl_group,
              row = hl.row,
              line_hl = true,
              priority = hl.priority or 5,
            })
          elseif hl.col_start ~= nil and hl.col_end ~= nil then
            el:place_extmark_highlight({
              hl = hl.hl_group,
              row = hl.row,
              col_range = {
                from = hl.col_start,
                to = hl.col_end > 0 and hl.col_end or nil,
              },
              priority = hl.col_priority or hl.priority or 10,
            })
          end
        end
      end

      local syntax_hls = syntax_hl_map[row]
      if syntax_hls then
        for _, hl in ipairs(syntax_hls) do
          el:place_extmark_highlight({
            hl = hl.hl_group,
            row = hl.row,
            col_range = {
              from = hl.col_start,
              to = hl.col_end >= 0 and hl.col_end or #(self.state.lines[row + 1] or ''),
            },
            priority = 20,
          })
        end
      end
    end

    return true
  end)

  if rendered then
    self:commit_viewport(top, bot)
    self:_schedule_syntax(top, bot)
  end
end

function PatchPreviewComponent:get_line_metadata(lnum)
  return self.state.line_metadata[lnum]
end

function PatchPreviewComponent:get_all_line_metadata()
  return self.state.line_metadata or {}
end

function PatchPreviewComponent:clear_lines()
  self:with_element(function(el)
    el:clear_extmarks()
    el:clear_lines()
  end)
  self.state.lines = {}
  self.state.line_metadata = {}
  return self
end

function PatchPreviewComponent:clear_extmarks()
  self:with_element(function(el)
    el:clear_extmarks()
  end)
  return self
end

function PatchPreviewComponent:render_folds()
  return self
end

function PatchPreviewComponent:clear_folds()
  return self
end

function PatchPreviewComponent:get_hunks()
  return {}
end

function PatchPreviewComponent:get_hunk_under_cursor()
  return nil
end

function PatchPreviewComponent:reset()
  DiffViewportComponent.reset(self)
  self.state.marks = {}
  self.state._line_numbers = {}
  self.state.line_metadata = {}
  self.state._diff_hl_map = {}
  self.state._syntax_hl_map = {}
  self.state._syntax_sections = {}
  return self
end

return PatchPreviewComponent
