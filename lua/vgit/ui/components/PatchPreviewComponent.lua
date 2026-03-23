local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local symbols_setting = lazy('vgit.settings.symbols')
local DiffAnnotator = lazy('vgit.ui.annotators.DiffAnnotator')
local DiffStyleAnnotator = lazy('vgit.ui.annotators.DiffStyleAnnotator')
local SyntaxMappingAnnotator = lazy('vgit.ui.annotators.SyntaxMappingAnnotator')
local DiffViewportComponent = lazy('vgit.ui.DiffViewportComponent')
local PatchLineBuilder = lazy('vgit.ui.components.PatchLineBuilder')

local PatchPreviewComponent = DiffViewportComponent:extend()

function PatchPreviewComponent:constructor(props)
  local instance = DiffViewportComponent.constructor(self, props)
  instance._syntax_mapping_annotator = SyntaxMappingAnnotator()
  instance._render_gen = 0
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
    _line_numbers = {},
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
    self.state._line_numbers = {}
    self:clear_lines()
    self:reset_cursor()
    return
  end

  local lines, line_metadata, file_sections, marks, line_numbers = PatchLineBuilder.build(hunk_entries)
  self.state.lines = lines
  self.state.line_metadata = line_metadata
  self.state.marks = marks or {}
  self.state._line_numbers = line_numbers or {}

  if #lines == 0 then
    self:clear_lines()
    self:reset_cursor()
    return
  end

  self:with_element(function(el)
    el:set_lines(lines)
    el:enable_cursorline()
  end)

  local diff_highlights = DiffStyleAnnotator.annotate(lines, line_metadata)
  self.state._diff_hl_map = self:_build_highlight_map(diff_highlights)

  self.state._syntax_hl_map = {}
  local sections = file_sections
  local gen = self._render_gen
  event.async(function()
    event.await()
    if not self._mounted or self._render_gen ~= gen then return end
    local syntax_highlights = self:_compute_syntax_highlights_from_full_files(sections)
    if not self._mounted or self._render_gen ~= gen then return end
    self.state._syntax_hl_map = self:_build_highlight_map(syntax_highlights)
    self:mark_viewport_dirty()
  end)()

  self:_ensure_renderer_attached()
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

function PatchPreviewComponent:_compute_syntax_highlights_from_full_files(file_sections)
  local all_highlights = {}

  for _, section in ipairs(file_sections or {}) do
    self:_resolve_section_syntax(all_highlights, section)
  end

  return all_highlights
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

      if meta and meta.lnum_change and meta.lnum_change.word_diff then
        local texts = DiffAnnotator.word_diff_to_texts(meta.lnum_change.word_diff, meta.lnum_change.type)
        if #texts > 0 then el:place_extmark_text({ row = row, col = 0, texts = texts }) end
      end

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
              to = hl.col_end > 0 and hl.col_end or nil,
            },
            priority = 20,
          })
        end
      end
    end

    return true
  end)

  if rendered then self:commit_viewport(top, bot) end
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
    el:clear_extmark_lnums()
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
  self.state.line_metadata = {}
  self.state._diff_hl_map = {}
  self.state._syntax_hl_map = {}
  return self
end

return PatchPreviewComponent
