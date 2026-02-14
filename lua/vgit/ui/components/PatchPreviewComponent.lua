local lazy = require('vgit.core.lazy')
local utils = lazy('vgit.core.utils')
local Component = lazy('vgit.ui.Component')
local ViewportComponent = lazy('vgit.ui.ViewportComponent')
local Element = lazy('vgit.ui.elements.Element')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')
local PatchHighlighter = lazy('vgit.ui.highlighters.PatchHighlighter')

local separator = string.rep('─', 60)

local PatchPreviewComponent = ViewportComponent:extend()

function PatchPreviewComponent:constructor(props)
  local instance = ViewportComponent.constructor(self, props)
  instance._element = nil
  instance._patch_highlighter = PatchHighlighter()
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

function PatchPreviewComponent:should_component_update(next_props, next_state)
  if self.props.patch_entries ~= next_props.patch_entries then return true end
  if self.props.hunks ~= next_props.hunks then return true end
  if self.props.filetype ~= next_props.filetype then return true end
  return false
end

function PatchPreviewComponent:component_did_mount()
  self:render()
end

function PatchPreviewComponent:component_did_update(prev_state)
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

function PatchPreviewComponent:build_patch_lines_from_entries(patch_entries)
  local lines = {}
  local line_metadata = {}
  local file_sections = {} -- For native TreeSitter highlighting
  local marks = {} -- Hunk markers for navigation

  local current_file_section = nil

  for _, entry in ipairs(patch_entries or {}) do
    if entry.type == 'file_header' then
      -- Save previous file section if exists
      if
        current_file_section
        and (current_file_section.line_count > 0 or (current_file_section.hunks and #current_file_section.hunks > 0))
      then
        current_file_section.end_row = #lines - 1
        file_sections[#file_sections + 1] = current_file_section
      end

      lines[#lines + 1] = separator
      line_metadata[#lines] = { type = 'separator' }

      lines[#lines + 1] = entry.filename or 'unknown'
      line_metadata[#lines] = { type = 'filename', filename = entry.filename }

      lines[#lines + 1] = separator
      line_metadata[#lines] = { type = 'separator' }

      -- Start new file section
      current_file_section = {
        filetype = entry.filetype,
        original_lines = entry.original_lines or {},
        current_lines = entry.current_lines or {},
        start_row = #lines,
        end_row = nil,
        line_count = 0,
        hunks = {},
      }
    elseif entry.type == 'diff_content' then
      -- Unified diff content (actual code without +/- prefixes)
      local diff_lines = entry.lines or {}
      local lnum_change_map = entry.lnum_change_map or {}
      local filetype = entry.filetype

      if current_file_section then current_file_section.start_row = #lines end

      for i, line in ipairs(diff_lines) do
        lines[#lines + 1] = line
        local lnum_change = lnum_change_map[i]
        line_metadata[#lines] = {
          type = 'code',
          filetype = filetype,
          lnum_change = lnum_change,
          original_lnum = i,
        }
      end

      if current_file_section then current_file_section.line_count = #diff_lines end

      lines[#lines + 1] = ''
      line_metadata[#lines] = { type = 'blank' }
    elseif entry.type == 'hunk' then
      local hunk = entry.hunk
      local filetype = entry.filetype

      -- Track hunk start for full-file highlighting (0-indexed for internal use)
      local hunk_start_row = #lines

      if hunk.header then
        lines[#lines + 1] = hunk.header
        line_metadata[#lines] = { type = 'code', filetype = filetype, is_header = true, hunk_header = hunk.header }
      end

      for _, diff_line in ipairs(hunk.diff or {}) do
        local prefix = diff_line:sub(1, 1)
        local cleaned_line = diff_line:sub(2) -- STRIP THE PREFIX

        lines[#lines + 1] = cleaned_line

        local change_type = nil
        if prefix == '+' then
          change_type = 'add'
        elseif prefix == '-' then
          change_type = 'remove'
        end

        line_metadata[#lines] = {
          type = 'code',
          filetype = filetype,
          lnum_change = change_type and { type = change_type } or nil,
        }
      end

      -- Track hunk end (1-indexed for cursor positioning)
      local hunk_end_row = #lines

      -- Add mark for hunk navigation (1-indexed line numbers)
      marks[#marks + 1] = {
        top = hunk_start_row + 1, -- 1-indexed
        bot = hunk_end_row, -- 1-indexed
      }

      -- Store hunk info for full-file highlighting
      if current_file_section then
        current_file_section.hunks = current_file_section.hunks or {}
        current_file_section.hunks[#current_file_section.hunks + 1] = {
          header = hunk.header,
          diff = hunk.diff or {},
          patch_start_row = hunk_start_row,
        }
        current_file_section.line_count = (current_file_section.line_count or 0)
          + #(hunk.diff or {})
          + (hunk.header and 1 or 0)
      end

      lines[#lines + 1] = ''
      line_metadata[#lines] = { type = 'blank' }
    end
  end

  -- Save last file section
  if
    current_file_section
    and (current_file_section.line_count > 0 or (current_file_section.hunks and #current_file_section.hunks > 0))
  then
    current_file_section.end_row = #lines - 1
    file_sections[#file_sections + 1] = current_file_section
  end

  if #lines > 0 and lines[#lines] == '' then
    table.remove(lines)
    line_metadata[#lines + 1] = nil
  end

  return lines, line_metadata, file_sections, marks
end

function PatchPreviewComponent:build_patch_lines(hunks, selected_hunk_index)
  local patch_lines = {}

  if selected_hunk_index and hunks[selected_hunk_index] then
    local hunk = hunks[selected_hunk_index]
    if hunk.header then patch_lines[#patch_lines + 1] = hunk.header end
    for _, line in ipairs(hunk.diff or {}) do
      patch_lines[#patch_lines + 1] = line
    end
  else
    for _, hunk in ipairs(hunks or {}) do
      if hunk.header then patch_lines[#patch_lines + 1] = hunk.header end
      for _, line in ipairs(hunk.diff or {}) do
        patch_lines[#patch_lines + 1] = line
      end
      patch_lines[#patch_lines + 1] = ''
    end

    if #patch_lines > 0 and patch_lines[#patch_lines] == '' then table.remove(patch_lines) end
  end

  return patch_lines
end

function PatchPreviewComponent:render()
  self:mark_viewport_dirty()
  self._render_gen = self._render_gen + 1

  -- Full clear of highlights since data is changing;
  -- viewport renderer will use ranged clear for scroll-only updates
  self:with_element(function(el)
    el:clear_extmark_highlights()
  end)

  local patch_entries = self.props.patch_entries
  local hunks = self.props.hunks
  local filetype = self.props.filetype
  local selected_hunk = self.props.selected_hunk

  local lines, line_metadata

  if patch_entries and #patch_entries > 0 then
    local file_sections, marks
    lines, line_metadata, file_sections, marks = self:build_patch_lines_from_entries(patch_entries)
    self.state.lines = lines
    self.state.line_metadata = line_metadata
    self.state.marks = marks or {}

    if #lines == 0 then
      self:clear_lines()
      self:reset_cursor()
      return
    end

    self:with_element(function(el)
      el:set_lines(lines)
      el:enable_cursorline()
    end)

    -- Compute highlights and cache in state for viewport rendering
    local diff_highlights = self._patch_highlighter:get_diff_line_highlights_with_metadata(lines, line_metadata)
    self.state._diff_hl_map = self:_build_highlight_map(diff_highlights)

    local line_numbers = self:calculate_line_numbers(lines, line_metadata)
    self.state._line_numbers = line_numbers

    self.state._syntax_hl_map = {}
    local sections = file_sections
    local gen = self._render_gen
    vim.schedule(function()
      if not self.mounted or self._render_gen ~= gen then return end
      local syntax_highlights = self:_compute_syntax_highlights_from_full_files(sections)
      self.state._syntax_hl_map = self:_build_highlight_map(syntax_highlights)
      self:mark_viewport_dirty()
    end)

    self:_ensure_renderer_attached()
  elseif hunks and #hunks > 0 then
    local patch_lines = self:build_patch_lines(hunks, selected_hunk)
    self.state.lines = patch_lines
    self.state.line_metadata = {}
    self.state.marks = {}

    self:with_element(function(el)
      el:set_lines(patch_lines)
      el:enable_cursorline()
    end)

    -- Compute highlights and cache in state for viewport rendering
    local diff_highlights = self._patch_highlighter:get_diff_line_highlights(patch_lines)
    self.state._diff_hl_map = self:_build_highlight_map(diff_highlights)

    self.state._syntax_hl_map = {}
    self.state._line_numbers = {}
    if filetype and filetype ~= '' and filetype ~= 'text' then
      local pl, ft = patch_lines, filetype
      local gen = self._render_gen
      vim.schedule(function()
        if not self.mounted or self._render_gen ~= gen then return end
        local syntax_highlights = self._patch_highlighter:highlight(pl, ft)
        self.state._syntax_hl_map = self:_build_highlight_map(syntax_highlights)
        self:mark_viewport_dirty()
      end)
    end

    self:_ensure_renderer_attached()
  else
    self.state.lines = {}
    self.state.line_metadata = {}
    self:clear_lines()
    self:reset_cursor()
  end
end

-- Calculate line numbers for delta-style display
-- Returns: { { text = ' 5 ', hl = 'GitSignsAdd' }, ... }
function PatchPreviewComponent:calculate_line_numbers(lines, line_metadata)
  local line_numbers = {}
  local max_lnum = 0

  -- Track line numbers based on hunk headers
  local current_orig_lnum = 1
  local current_curr_lnum = 1

  -- First pass: find max line number for padding
  for i, _ in ipairs(lines) do
    local meta = line_metadata[i]
    if meta and meta.type == 'code' then
      if meta.is_header and meta.hunk_header then
        local orig_start, curr_start = self._patch_highlighter:parse_hunk_header(meta.hunk_header)
        current_orig_lnum = orig_start
        current_curr_lnum = curr_start
      else
        local lnum_change = meta.lnum_change
        if lnum_change and lnum_change.type == 'remove' then
          if current_orig_lnum > max_lnum then max_lnum = current_orig_lnum end
          current_orig_lnum = current_orig_lnum + 1
        elseif lnum_change and lnum_change.type == 'add' then
          if current_curr_lnum > max_lnum then max_lnum = current_curr_lnum end
          current_curr_lnum = current_curr_lnum + 1
        else
          if current_curr_lnum > max_lnum then max_lnum = current_curr_lnum end
          current_orig_lnum = current_orig_lnum + 1
          current_curr_lnum = current_curr_lnum + 1
        end
      end
    end
  end

  local max_digits = math.max(3, string.len(tostring(max_lnum)))
  local lnum_fmt = '%' .. max_digits .. 'd '
  local empty_text = string.rep(' ', max_digits + 1)

  -- Second pass: build line number display
  current_orig_lnum = 1
  current_curr_lnum = 1

  for i, _ in ipairs(lines) do
    local meta = line_metadata[i]

    if not meta or meta.type == 'separator' or meta.type == 'blank' then
      -- No line number for separators, blank lines
      line_numbers[#line_numbers + 1] = { text = empty_text, hl = 'GitLineNr' }
    elseif meta.type == 'filename' then
      -- No line number for filename
      line_numbers[#line_numbers + 1] = { text = empty_text, hl = 'GitLineNr' }
    elseif meta.type == 'code' then
      if meta.is_header and meta.hunk_header then
        -- Parse hunk header to reset counters
        local orig_start, curr_start = self._patch_highlighter:parse_hunk_header(meta.hunk_header)
        current_orig_lnum = orig_start
        current_curr_lnum = curr_start
        -- No line number for hunk headers
        line_numbers[#line_numbers + 1] = { text = empty_text, hl = 'GitPatchHeader' }
      else
        local lnum_change = meta.lnum_change
        local lnum_text
        local hl_group

        if lnum_change and lnum_change.type == 'remove' then
          -- Removed lines: show original file line number with delete highlight
          lnum_text = string.format(lnum_fmt, current_orig_lnum)
          hl_group = 'GitSignsDelete'
          current_orig_lnum = current_orig_lnum + 1
        elseif lnum_change and lnum_change.type == 'add' then
          -- Added lines: show current file line number with add highlight
          lnum_text = string.format(lnum_fmt, current_curr_lnum)
          hl_group = 'GitSignsAdd'
          current_curr_lnum = current_curr_lnum + 1
        else
          -- Context lines: show current file line number
          lnum_text = string.format(lnum_fmt, current_curr_lnum)
          hl_group = 'GitLineNr'
          current_orig_lnum = current_orig_lnum + 1
          current_curr_lnum = current_curr_lnum + 1
        end

        line_numbers[#line_numbers + 1] = { text = lnum_text, hl = hl_group }
      end
    else
      line_numbers[#line_numbers + 1] = { text = empty_text, hl = 'GitLineNr' }
    end
  end

  return line_numbers
end

-- Compute syntax highlights from full files without placing extmarks
function PatchPreviewComponent:_compute_syntax_highlights_from_full_files(file_sections)
  local all_highlights = {}

  for _, section in ipairs(file_sections or {}) do
    local filetype = section.filetype
    local hunks = section.hunks

    if filetype and filetype ~= '' and filetype ~= 'text' and hunks and #hunks > 0 then
      local highlights = self._patch_highlighter:highlight_from_full_files({
        original_lines = section.original_lines,
        current_lines = section.current_lines,
        filetype = filetype,
        hunks = hunks,
        strip_prefix = true,
      })

      for _, hl in ipairs(highlights) do
        all_highlights[#all_highlights + 1] = hl
      end
    end
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

  -- Single with_element call for entire viewport — avoids per-row validity checks
  local rendered = self:with_element(function(el)
    -- Ranged clear: only remove highlights in the viewport being re-rendered.
    -- Full clear already happened in render() on data change.
    el:clear_extmark_highlights(top, bot)

    local diff_hl_map = self.state._diff_hl_map
    local syntax_hl_map = self.state._syntax_hl_map
    local line_numbers = self.state._line_numbers

    for row = top, bot do
      -- Render line number for this row
      local ln = line_numbers[row + 1] -- 1-indexed
      if ln then
        el:place_extmark_lnum({
          row = row,
          hl = ln.hl,
          text = ln.text,
        })
      end

      -- Render diff background highlights for this row
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

      -- Render syntax highlights for this row
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
  return self:with_element(function(el) return el:get_lines() end) or self.state.lines
end

function PatchPreviewComponent:clear_lines()
  self:with_element(function(el) el:clear_lines() end)
  self.state.lines = {}
  self.state.line_metadata = {}
  return self
end

function PatchPreviewComponent:set_cursor(cursor)
  self:with_element(function(el) el:set_cursor(cursor) end)
  return self
end

function PatchPreviewComponent:get_cursor()
  return self:with_element(function(el) return el:get_cursor() end) or { 1, 1 }
end

function PatchPreviewComponent:set_lnum(lnum)
  self:with_element(function(el) el:set_lnum(lnum) end)
  return self
end

function PatchPreviewComponent:get_lnum()
  return self:with_element(function(el) return el:get_lnum() end) or 1
end

function PatchPreviewComponent:reset_cursor()
  return self:set_cursor({ 1, 0 })
end

function PatchPreviewComponent:enable_cursorline()
  self:with_element(function(el) el:enable_cursorline() end)
  return self
end

function PatchPreviewComponent:disable_cursorline()
  self:with_element(function(el) el:disable_cursorline() end)
  return self
end

function PatchPreviewComponent:get_line_count()
  return self:with_element(function(el) return el:get_line_count() end) or 0
end

function PatchPreviewComponent:position_cursor(pos)
  self:with_element(function(el)
    pos = pos or 'center'
    local win_id = el:get_win_id()
    if not win_id then return end

    if pos == 'top' then
      vim.api.nvim_win_call(win_id, function()
        vim.cmd('normal! zt')
      end)
    elseif pos == 'center' then
      vim.api.nvim_win_call(win_id, function()
        vim.cmd('normal! zz')
      end)
    elseif pos == 'bottom' then
      vim.api.nvim_win_call(win_id, function()
        vim.cmd('normal! zb')
      end)
    end
  end)

  return self
end

function PatchPreviewComponent:move_to_hunk(mark_index, pos)
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
    self:position_cursor(pos)
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

function PatchPreviewComponent:hunk_down(pos)
  local mark_index = self:find_adjacent_mark_index('next')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos)
end

function PatchPreviewComponent:hunk_up(pos)
  local mark_index = self:find_adjacent_mark_index('prev')
  if not mark_index then return nil end
  return self:move_to_hunk(mark_index, pos)
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
  self:with_element(function(el) el:set_keymap(config, handler) end)
  return self
end

function PatchPreviewComponent:is_valid()
  return self:with_element(function() return true end) or false
end

function PatchPreviewComponent:focus()
  if self._element then self._element:focus() end
end

function PatchPreviewComponent:call(callback)
  if callback then self:with_element(function(el) el:call(callback) end) end
  return self
end

function PatchPreviewComponent:unmount()
  if not self.mounted then return end

  self._element:unmount()
  self._element = nil

  ViewportComponent.unmount(self)
end

return PatchPreviewComponent
