local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Window = lazy('vgit.core.Window')
local Component = lazy('vgit.ui.Component')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local ViewportComponent = lazy('vgit.ui.ViewportComponent')
local symbols_setting = lazy('vgit.settings.symbols')
local DiffStyleAnnotator = lazy('vgit.ui.annotators.DiffStyleAnnotator')
local SyntaxMappingAnnotator = lazy('vgit.ui.annotators.SyntaxMappingAnnotator')

local separator = string.rep('─', 60)
local CONTEXT = 3

local function compute_visible_ranges(marks, total_lines)
  if not marks or #marks == 0 then return {} end

  local ranges = {}
  for _, mark in ipairs(marks) do
    local range_start = math.max(1, mark.top - CONTEXT)
    local range_end = math.min(total_lines, mark.bot + CONTEXT)
    ranges[#ranges + 1] = { range_start, range_end }
  end

  table.sort(ranges, function(a, b)
    return a[1] < b[1]
  end)
  local merged = { ranges[1] }
  for i = 2, #ranges do
    local prev = merged[#merged]
    if ranges[i][1] <= prev[2] + 1 then
      prev[2] = math.max(prev[2], ranges[i][2])
    else
      merged[#merged + 1] = ranges[i]
    end
  end

  return merged
end

local function advance_source_counters(lnum_change_map, from, to)
  local orig_delta = 0
  local curr_delta = 0
  for i = from, to do
    local lc = lnum_change_map[i]
    local ct = lc and lc.type or nil
    if ct == 'void' then
      -- no counter advance
    elseif ct == 'remove' then
      orig_delta = orig_delta + 1
    elseif ct == 'add' then
      curr_delta = curr_delta + 1
    else
      orig_delta = orig_delta + 1
      curr_delta = curr_delta + 1
    end
  end
  return orig_delta, curr_delta
end

local function parse_hunk_header(header)
  if not header then return 1, 1 end
  local orig_start, curr_start = header:match('@@ %-(%d+),?%d* %+(%d+),?%d* @@')
  if not orig_start then
    orig_start, curr_start = header:match('@@ %-(%d+) %+(%d+) @@')
  end
  return tonumber(orig_start) or 1, tonumber(curr_start) or 1
end

local function flush_file_section(ctx)
  local section = ctx.file_section
  if section and (section.line_count > 0 or (section.syntax_mappings and #section.syntax_mappings > 0)) then
    section.end_row = #ctx.lines - 1
    ctx.file_sections[#ctx.file_sections + 1] = section
  end
end

local function track_lnum(ctx, change_type, syntax_mapping)
  if change_type == 'remove' then
    if ctx.orig_lnum > ctx.max_lnum then ctx.max_lnum = ctx.orig_lnum end
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = ctx.orig_lnum, hl = 'GitSignsDelete' }
    if syntax_mapping and ctx.file_section then
      local sm = ctx.file_section.syntax_mappings
      sm[#sm + 1] = syntax_mapping
    end
    ctx.orig_lnum = ctx.orig_lnum + 1
  elseif change_type == 'add' then
    if ctx.curr_lnum > ctx.max_lnum then ctx.max_lnum = ctx.curr_lnum end
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = ctx.curr_lnum, hl = 'GitSignsAdd' }
    if syntax_mapping and ctx.file_section then
      local sm = ctx.file_section.syntax_mappings
      sm[#sm + 1] = syntax_mapping
    end
    ctx.curr_lnum = ctx.curr_lnum + 1
  elseif change_type == 'void' then
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }
  else
    if ctx.curr_lnum > ctx.max_lnum then ctx.max_lnum = ctx.curr_lnum end
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = ctx.curr_lnum, hl = 'GitLineNr' }
    if syntax_mapping and ctx.file_section then
      local sm = ctx.file_section.syntax_mappings
      sm[#sm + 1] = syntax_mapping
    end
    ctx.orig_lnum = ctx.orig_lnum + 1
    ctx.curr_lnum = ctx.curr_lnum + 1
  end
end

local function process_file_header(ctx, entry)
  flush_file_section(ctx)

  ctx.lines[#ctx.lines + 1] = separator
  ctx.line_metadata[#ctx.lines] = { type = 'separator' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.lines[#ctx.lines + 1] = entry.filename or 'unknown'
  ctx.line_metadata[#ctx.lines] = { type = 'filename', filename = entry.filename }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.lines[#ctx.lines + 1] = separator
  ctx.line_metadata[#ctx.lines] = { type = 'separator' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.file_section = {
    filetype = entry.filetype,
    original_lines = entry.original_lines or {},
    current_lines = entry.current_lines or {},
    start_row = #ctx.lines,
    end_row = nil,
    line_count = 0,
    syntax_mappings = {},
  }
end

local function process_diff_content(ctx, entry)
  local diff_lines = entry.lines or {}
  local lnum_change_map = entry.lnum_change_map or {}
  local filetype = entry.filetype

  if ctx.file_section then ctx.file_section.start_row = #ctx.lines end

  for i, line in ipairs(diff_lines) do
    ctx.lines[#ctx.lines + 1] = line
    local lnum_change = lnum_change_map[i]
    ctx.line_metadata[#ctx.lines] = {
      type = 'code',
      filetype = filetype,
      lnum_change = lnum_change,
      original_lnum = i,
    }

    local change_type = lnum_change and lnum_change.type or nil
    track_lnum(ctx, change_type)
  end

  if ctx.file_section then ctx.file_section.line_count = #diff_lines end

  ctx.lines[#ctx.lines + 1] = ''
  ctx.line_metadata[#ctx.lines] = { type = 'blank' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }
end

local function process_hunk(ctx, entry)
  local hunk = entry.hunk
  local filetype = entry.filetype

  local hunk_start_row = #ctx.lines

  if hunk.header then
    local orig_start, curr_start = parse_hunk_header(hunk.header)
    ctx.orig_lnum = orig_start
    ctx.curr_lnum = curr_start

    ctx.lines[#ctx.lines + 1] = hunk.header
    ctx.line_metadata[#ctx.lines] = { type = 'code', filetype = filetype, is_header = true, hunk_header = hunk.header }
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitPatchHeader' }
  end

  for i, diff_line in ipairs(hunk.diff or {}) do
    local prefix = diff_line:sub(1, 1)
    local cleaned_line = diff_line:sub(2)

    ctx.lines[#ctx.lines + 1] = cleaned_line
    local display_row = #ctx.lines - 1

    -- hunk.lnum_changes carries conflict-type metadata that overrides prefix-derived type.
    local lnum_change = hunk.lnum_changes and hunk.lnum_changes[i]
    local change_type
    if lnum_change then
      change_type = lnum_change.type
    elseif prefix == '+' then
      change_type = 'add'
    elseif prefix == '-' then
      change_type = 'remove'
    end

    ctx.line_metadata[#ctx.lines] = {
      type = 'code',
      filetype = filetype,
      lnum_change = change_type and { type = change_type } or nil,
    }

    local syntax_mapping
    if change_type == 'remove' then
      syntax_mapping = { source = 'original', source_line = ctx.orig_lnum, display_row = display_row }
    elseif change_type ~= 'void' and not lnum_change then
      syntax_mapping = { source = 'current', source_line = ctx.curr_lnum, display_row = display_row }
    end

    track_lnum(ctx, change_type, syntax_mapping)
  end

  local hunk_end_row = #ctx.lines

  ctx.marks[#ctx.marks + 1] = {
    top = hunk_start_row + 1,
    bot = hunk_end_row,
  }

  if ctx.file_section then
    ctx.file_section.line_count = (ctx.file_section.line_count or 0) + #(hunk.diff or {}) + (hunk.header and 1 or 0)
  end

  ctx.lines[#ctx.lines + 1] = ''
  ctx.line_metadata[#ctx.lines] = { type = 'blank' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }
end

local function process_diff_file(ctx, entry)
  local diff = entry.diff
  local buftype = entry.buftype
  local filetype = entry.filetype
  local raw_filename = entry.filename or 'unknown'
  local filename = raw_filename:match('^.+ %-> (.+)$') or raw_filename

  flush_file_section(ctx)

  ctx.lines[#ctx.lines + 1] = separator
  ctx.line_metadata[#ctx.lines] = { type = 'separator' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.lines[#ctx.lines + 1] = raw_filename
  ctx.line_metadata[#ctx.lines] = { type = 'filename', filename = raw_filename }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.lines[#ctx.lines + 1] = separator
  ctx.line_metadata[#ctx.lines] = { type = 'separator' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }

  ctx.file_section = {
    filetype = filetype,
    original_lines = entry.original_lines or {},
    current_lines = entry.current_lines or {},
    start_row = #ctx.lines,
    end_row = nil,
    line_count = 0,
    syntax_mappings = {},
  }

  local display_lines
  if buftype == 'current' then
    display_lines = diff.current_lines or {}
  elseif buftype == 'previous' then
    display_lines = diff.previous_lines or {}
  else
    display_lines = diff.lines or {}
  end

  local lnum_change_map = {}
  for _, lc in ipairs(diff.lnum_changes or {}) do
    if not buftype or lc.buftype == buftype then lnum_change_map[lc.lnum] = lc end
  end

  local visible_ranges = compute_visible_ranges(diff.marks, #display_lines)

  if #visible_ranges == 0 then
    ctx.lines[#ctx.lines + 1] = ''
    ctx.line_metadata[#ctx.lines] = { type = 'blank' }
    ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }
    return
  end

  ctx.orig_lnum = 1
  ctx.curr_lnum = 1

  if visible_ranges[1][1] > 1 then
    local od, cd = advance_source_counters(lnum_change_map, 1, visible_ranges[1][1] - 1)
    ctx.orig_lnum = ctx.orig_lnum + od
    ctx.curr_lnum = ctx.curr_lnum + cd
  end

  local original_to_rendered = {}
  local mark_offset = #ctx.lines
  local rendered_line_count = 0

  for range_idx, range in ipairs(visible_ranges) do
    if range_idx > 1 then
      local prev_end = visible_ranges[range_idx - 1][2]
      if range[1] > prev_end + 1 then
        local od, cd = advance_source_counters(lnum_change_map, prev_end + 1, range[1] - 1)
        ctx.orig_lnum = ctx.orig_lnum + od
        ctx.curr_lnum = ctx.curr_lnum + cd
      end

      local header = string.format('@@ -%d +%d @@', ctx.orig_lnum, ctx.curr_lnum)
      ctx.lines[#ctx.lines + 1] = header
      ctx.line_metadata[#ctx.lines] = { type = 'code', filetype = filetype, is_header = true, hunk_header = header }
      ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitPatchHeader' }
    end

    for i = range[1], range[2] do
      local line = display_lines[i]
      ctx.lines[#ctx.lines + 1] = line
      local display_row = #ctx.lines - 1
      rendered_line_count = rendered_line_count + 1

      original_to_rendered[i] = #ctx.lines - mark_offset

      local lc = lnum_change_map[i]
      local change_type = lc and lc.type or nil

      local file_lnum
      if change_type == 'void' then
        file_lnum = nil
      elseif change_type == 'remove' then
        file_lnum = ctx.orig_lnum
      else
        file_lnum = ctx.curr_lnum
      end

      ctx.line_metadata[#ctx.lines] = {
        type = 'code',
        filetype = filetype,
        lnum_change = lc,
        file_lnum = file_lnum,
        filename = filename,
      }

      local syntax_mapping
      if change_type == 'void' then
        -- no mapping, no counter increment
      elseif change_type == 'remove' then
        syntax_mapping = { source = 'original', source_line = ctx.orig_lnum, display_row = display_row }
        ctx.orig_lnum = ctx.orig_lnum + 1
      elseif change_type == 'add' then
        syntax_mapping = { source = 'current', source_line = ctx.curr_lnum, display_row = display_row }
        ctx.curr_lnum = ctx.curr_lnum + 1
      else
        syntax_mapping = { source = 'current', source_line = ctx.curr_lnum, display_row = display_row }
        ctx.orig_lnum = ctx.orig_lnum + 1
        ctx.curr_lnum = ctx.curr_lnum + 1
      end

      local lnum_val
      if change_type == 'void' then
        lnum_val = nil
      elseif change_type == 'remove' then
        lnum_val = ctx.orig_lnum - 1
      elseif change_type == 'add' then
        lnum_val = ctx.curr_lnum - 1
      else
        lnum_val = ctx.curr_lnum - 1
      end

      if lnum_val and lnum_val > ctx.max_lnum then ctx.max_lnum = lnum_val end

      local hl = 'GitLineNr'
      if change_type == 'remove' then
        hl = 'GitSignsDelete'
      elseif change_type == 'add' then
        hl = 'GitSignsAdd'
      end

      ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = lnum_val, hl = hl }

      if syntax_mapping and ctx.file_section then
        local sm = ctx.file_section.syntax_mappings
        sm[#sm + 1] = syntax_mapping
      end
    end
  end

  for _, mark in ipairs(diff.marks or {}) do
    local new_top = original_to_rendered[mark.top]
    local new_bot = original_to_rendered[mark.bot]
    if new_top and new_bot then
      ctx.marks[#ctx.marks + 1] = {
        top = mark_offset + new_top,
        bot = mark_offset + new_bot,
      }
    end
  end

  if ctx.file_section then ctx.file_section.line_count = rendered_line_count end

  ctx.lines[#ctx.lines + 1] = ''
  ctx.line_metadata[#ctx.lines] = { type = 'blank' }
  ctx.raw_lnums[#ctx.raw_lnums + 1] = { lnum = nil, hl = 'GitLineNr' }
end

local function format_line_numbers(raw_lnums, max_lnum)
  local max_digits = math.max(3, string.len(tostring(max_lnum)))
  local lnum_fmt = '%' .. max_digits .. 'd '
  local empty_text = string.rep(' ', max_digits + 1)

  local line_numbers = {}
  for _, entry in ipairs(raw_lnums) do
    if entry.lnum then
      line_numbers[#line_numbers + 1] = { text = string.format(lnum_fmt, entry.lnum), hl = entry.hl }
    else
      line_numbers[#line_numbers + 1] = { text = empty_text, hl = entry.hl }
    end
  end

  return line_numbers
end

local PatchPreviewComponent = ViewportComponent:extend()

function PatchPreviewComponent:constructor(props)
  local instance = ViewportComponent.constructor(self, props)
  instance._element = nil
  instance._diff_style_annotator = DiffStyleAnnotator()
  instance._syntax_mapping_annotator = SyntaxMappingAnnotator()
  instance._render_gen = 0
  return instance
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

function PatchPreviewComponent:should_component_update(next_props)
  if self.props.hunk_entries ~= next_props.hunk_entries then return true end
  return false
end

function PatchPreviewComponent:component_did_mount()
  self:render()
end

function PatchPreviewComponent:component_did_update()
  self:render()
end

function PatchPreviewComponent:component_will_mount()
  if not self._element then
    local default_win_options = {
      winhl = 'Normal:GitBackground',
      signcolumn = 'no',
      wrap = false,
      number = false,
      cursorline = true,
    }

    local win_options = utils.object.assign(default_win_options, self.props.win_options or {})

    self._element = Element({
      buf_options = {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
        filetype = 'diff',
      },
      win_options = win_options,
    })
  end
end

function PatchPreviewComponent:build_patch_lines_from_entries(hunk_entries)
  local ctx = {
    lines = {},
    line_metadata = {},
    file_sections = {},
    marks = {},
    raw_lnums = {},
    file_section = nil,
    orig_lnum = 1,
    curr_lnum = 1,
    max_lnum = 0,
  }

  for _, entry in ipairs(hunk_entries or {}) do
    if entry.type == 'file_header' then
      process_file_header(ctx, entry)
    elseif entry.type == 'diff_content' then
      process_diff_content(ctx, entry)
    elseif entry.type == 'hunk' then
      process_hunk(ctx, entry)
    elseif entry.type == 'diff_file' then
      process_diff_file(ctx, entry)
    end
  end

  flush_file_section(ctx)

  if #ctx.lines > 0 and ctx.lines[#ctx.lines] == '' then
    table.remove(ctx.lines)
    ctx.line_metadata[#ctx.lines + 1] = nil
    table.remove(ctx.raw_lnums)
  end

  return ctx.lines, ctx.line_metadata, ctx.file_sections, ctx.marks, format_line_numbers(ctx.raw_lnums, ctx.max_lnum)
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
    self:clear_lines()
    self:reset_cursor()
    return
  end

  local lines, line_metadata, file_sections, marks, line_numbers = self:build_patch_lines_from_entries(hunk_entries)
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

  local diff_highlights = self._diff_style_annotator:annotate(lines, line_metadata)
  self.state._diff_hl_map = self:_build_highlight_map(diff_highlights)

  self.state._syntax_hl_map = {}
  local sections = file_sections
  local gen = self._render_gen
  vim.schedule(function()
    if not self._mounted or self._render_gen ~= gen then return end
    local syntax_highlights = self:_compute_syntax_highlights_from_full_files(sections)
    self.state._syntax_hl_map = self:_build_highlight_map(syntax_highlights)
    self:mark_viewport_dirty()
  end)

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

function PatchPreviewComponent:_render_viewport(top, bot)
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
        local word_diff = meta.lnum_change.word_diff
        local change_type = meta.lnum_change.type
        local texts = {}
        for _, segment in ipairs(word_diff) do
          local operation, fragment = unpack(segment)
          if operation == -1 then
            local hl = change_type == 'remove' and 'GitWordDelete' or 'GitWordAdd'
            texts[#texts + 1] = { fragment, hl }
          elseif operation == 0 then
            texts[#texts + 1] = { fragment, nil }
          end
        end
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

function PatchPreviewComponent:_ensure_renderer_attached()
  self:ensure_renderer_attached(function()
    self:with_element(function(el)
      el:attach_to_renderer(function(top, bot)
        self:_render_viewport(top, bot)
      end)
    end)
  end)
end

function PatchPreviewComponent:get_layout_spec()
  return LayoutSpec.view(self._element, {
    id = self.props.id or 'patch_preview',
    flex = self.props.flex or 1,
    focus = self.props.focus or false,
  })
end

function PatchPreviewComponent:get_marks()
  return self.state.marks or {}
end

function PatchPreviewComponent:get_line_metadata(lnum)
  return self.state.line_metadata[lnum]
end

function PatchPreviewComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end) or self.state.lines
end

function PatchPreviewComponent:clear_lines()
  self:with_element(function(el)
    el:clear_lines()
  end)
  self.state.lines = {}
  self.state.line_metadata = {}
  return self
end

function PatchPreviewComponent:set_cursor(cursor)
  self:with_element(function(el)
    el:set_cursor(cursor)
  end)
  return self
end

function PatchPreviewComponent:get_cursor()
  return self:with_element(function(el)
    return el:get_cursor()
  end) or { 1, 1 }
end

function PatchPreviewComponent:set_lnum(lnum)
  self:with_element(function(el)
    el:set_lnum(lnum)
  end)
  return self
end

function PatchPreviewComponent:get_lnum()
  return self:with_element(function(el)
    return el:get_lnum()
  end) or 1
end

function PatchPreviewComponent:reset_cursor()
  return self:set_cursor({ 1, 0 })
end

function PatchPreviewComponent:enable_cursorline()
  self:with_element(function(el)
    el:enable_cursorline()
  end)
  return self
end

function PatchPreviewComponent:disable_cursorline()
  self:with_element(function(el)
    el:disable_cursorline()
  end)
  return self
end

function PatchPreviewComponent:get_line_count()
  return self:with_element(function(el)
    return el:get_line_count()
  end) or 0
end

function PatchPreviewComponent:scroll_to(pos, offset)
  self:with_element(function(el)
    pos = pos or 'center'
    offset = offset or 0
    local win = el:get_window()
    if not win then return end
    win:scroll_to(pos, offset)
  end)

  return self
end

function PatchPreviewComponent:move_to_hunk(mark_index, pos, offset)
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
  if mark then
    self:set_lnum(mark.top)
    self:scroll_to(pos, offset)
    return mark
  end

  return nil
end

function PatchPreviewComponent:find_adjacent_mark_index(direction)
  local marks = self.state.marks
  if not marks or #marks == 0 then return nil end

  local lnum = self:get_lnum()
  local num_marks = #marks

  if direction == 'next' then
    for i = 1, num_marks do
      local mark = marks[i]
      if lnum >= mark.top and lnum <= mark.bot then
        return i + 1
      elseif mark.top > lnum then
        return i
      end
    end
    return 1
  else
    for i = num_marks, 1, -1 do
      local mark = marks[i]
      if lnum >= mark.top and lnum <= mark.bot then
        return i - 1
      elseif mark.top < lnum then
        return i
      end
    end
    return num_marks
  end
end

function PatchPreviewComponent:hunk_down(pos, offset)
  local mark_index = self:find_adjacent_mark_index('next')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

function PatchPreviewComponent:hunk_up(pos, offset)
  local mark_index = self:find_adjacent_mark_index('prev')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos, offset)
end

Component.forward(PatchPreviewComponent, function(self)
  return self._element and self._element:is_valid() and self._element
end, {
  'place_extmark_highlight',
})

function PatchPreviewComponent:clear_extmarks()
  self:with_element(function(el)
    el:clear_extmarks()
    el:clear_extmark_lnums()
  end)
  return self
end

function PatchPreviewComponent:set_keymap(config, handler)
  self:with_element(function(el)
    el:set_keymap(config, handler)
  end)
  return self
end

function PatchPreviewComponent:is_valid()
  return self:with_element(function()
    return true
  end) or false
end

function PatchPreviewComponent:focus()
  self:with_element(function(el)
    el:focus()
  end)
end

function PatchPreviewComponent:call(callback)
  if callback then self:with_element(function(el)
    el:call(callback)
  end) end
  return self
end

function PatchPreviewComponent:unmount()
  if not self._mounted then return end

  self._element:unmount()
  self._element = nil

  ViewportComponent.unmount(self)
end

return PatchPreviewComponent
