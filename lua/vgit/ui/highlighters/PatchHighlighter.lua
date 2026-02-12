local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local PatchHighlighter = Object:extend()

function PatchHighlighter:constructor()
  return {
    _parser_cache = {},
  }
end

-- Determine the diff line type from line content or metadata
local function get_line_diff_type(line, meta)
  if meta and meta.lnum_change and meta.lnum_change.type then
    return meta.lnum_change.type
  end

  if meta and meta.is_header then
    return 'header'
  end

  if not line then return nil end

  local prefix = line:sub(1, 1)
  if prefix == '+' then
    return 'add'
  elseif prefix == '-' then
    return 'remove'
  elseif prefix == ' ' then
    return 'context'
  elseif line:match('^@@') then
    return 'header'
  end

  return nil
end

function PatchHighlighter:strip_patch_prefix(line)
  if not line or #line == 0 then
    return '', nil
  end

  local prefix = line:sub(1, 1)
  if prefix == '+' or prefix == '-' or prefix == ' ' then
    return line:sub(2), prefix
  end

  return line, nil
end

function PatchHighlighter:extract_code_lines(patch_lines)
  local code_lines = {}
  local line_mapping = {}

  for i, line in ipairs(patch_lines) do
    if line:match('^@@') then
      code_lines[#code_lines + 1] = ''
      line_mapping[#code_lines] = { patch_lnum = i, is_header = true }
    else
      local code, prefix = self:strip_patch_prefix(line)
      code_lines[#code_lines + 1] = code
      line_mapping[#code_lines] = { patch_lnum = i, prefix = prefix }
    end
  end

  return code_lines, line_mapping
end

function PatchHighlighter:create_scratch_buffer(code_lines, filetype)
  local bufnr = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, code_lines)

  if filetype and filetype ~= '' then
    vim.api.nvim_set_option_value('filetype', filetype, { buf = bufnr })
  end

  return bufnr
end

function PatchHighlighter:get_treesitter_highlights(bufnr, filetype)
  local highlights = {}

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, filetype)
  if not ok or not parser then
    return highlights
  end

  local query_ok, query = pcall(vim.treesitter.query.get, filetype, 'highlights')
  if not query_ok or not query then
    return highlights
  end

  local tree = parser:parse()[1]
  if not tree then
    return highlights
  end

  local root = tree:root()

  for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    for row = start_row, end_row do
      local col_start = (row == start_row) and start_col or 0
      local col_end = (row == end_row) and end_col or -1

      highlights[#highlights + 1] = {
        row = row,
        col_start = col_start,
        col_end = col_end,
        hl_group = '@' .. name,
      }
    end
  end

  return highlights
end

function PatchHighlighter:adjust_highlights_for_patch(highlights, line_mapping)
  local adjusted = {}
  local prefix_offset = 1

  for _, hl in ipairs(highlights) do
    local lnum = hl.row + 1
    local mapping = line_mapping[lnum]

    if mapping and not mapping.is_header then
      adjusted[#adjusted + 1] = {
        row = mapping.patch_lnum - 1,
        col_start = hl.col_start + prefix_offset,
        col_end = hl.col_end > 0 and (hl.col_end + prefix_offset) or -1,
        hl_group = hl.hl_group,
      }
    end
  end

  return adjusted
end

function PatchHighlighter:highlight(patch_lines, filetype)
  if not patch_lines or #patch_lines == 0 then
    return {}
  end

  if not filetype or filetype == '' or filetype == 'text' then
    return {}
  end

  local code_lines, line_mapping = self:extract_code_lines(patch_lines)

  if #code_lines == 0 then
    return {}
  end

  local bufnr = self:create_scratch_buffer(code_lines, filetype)

  local highlights = self:get_treesitter_highlights(bufnr, filetype)

  local adjusted_highlights = self:adjust_highlights_for_patch(highlights, line_mapping)

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_delete(bufnr, { force = true })
    end
  end)

  return adjusted_highlights
end

function PatchHighlighter:highlight_with_metadata(lines, line_metadata)
  if not lines or #lines == 0 then
    return {}
  end

  local sections = {}
  local current_section = nil

  for i, line in ipairs(lines) do
    local meta = line_metadata[i]
    if meta and meta.type == 'code' and meta.filetype and meta.filetype ~= '' then
      local filetype = meta.filetype
      if not current_section or current_section.filetype ~= filetype then
        if current_section then
          sections[#sections + 1] = current_section
        end
        current_section = {
          filetype = filetype,
          lines = {},
          line_indices = {},
        }
      end
      current_section.lines[#current_section.lines + 1] = line
      current_section.line_indices[#current_section.line_indices + 1] = i
    else
      if current_section then
        sections[#sections + 1] = current_section
        current_section = nil
      end
    end
  end

  if current_section then
    sections[#sections + 1] = current_section
  end

  local all_highlights = {}

  for _, section in ipairs(sections) do
    local section_highlights = self:highlight(section.lines, section.filetype)

    for _, hl in ipairs(section_highlights) do
      local original_row = hl.row + 1
      if original_row <= #section.line_indices then
        local actual_row = section.line_indices[original_row]
        all_highlights[#all_highlights + 1] = {
          row = actual_row - 1,
          col_start = hl.col_start,
          col_end = hl.col_end,
          hl_group = hl.hl_group,
        }
      end
    end
  end

  return all_highlights
end

function PatchHighlighter:get_hunk_header_highlights(line, row)
  local highlights = {}

  -- Add background highlight for entire line first
  highlights[#highlights + 1] = {
    row = row,
    hl_group = 'GitPatchHeader',
    line = true,
  }

  -- Pattern: @@ -N,M +N,M @@ optional_context
  -- Add highlight for opening @@
  highlights[#highlights + 1] = {
    row = row,
    col_start = 0,
    col_end = 2,
    hl_group = 'GitPatchHeaderMarker',
  }

  -- Find and highlight -N,M portion
  local minus_start, minus_end = line:find('%-[%d,]+')
  if minus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = minus_start - 1,
      col_end = minus_end,
      hl_group = 'GitPatchHeaderRemove',
    }
  end

  -- Find and highlight +N,M portion
  local plus_start, plus_end = line:find('%+[%d,]+')
  if plus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = plus_start - 1,
      col_end = plus_end,
      hl_group = 'GitPatchHeaderAdd',
    }
  end

  -- Find closing @@
  local close_start = line:find(' @@', plus_end or minus_end or 2)
  if close_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = close_start,
      col_end = close_start + 2,
      hl_group = 'GitPatchHeaderMarker',
    }
  end

  return highlights
end

function PatchHighlighter:get_diff_line_highlights(patch_lines)
  local diff_highlights = {}

  for i, line in ipairs(patch_lines) do
    local row = i - 1
    local diff_type = get_line_diff_type(line, nil)

    if diff_type == 'header' then
      local header_highlights = self:get_hunk_header_highlights(line, row)
      for _, hl in ipairs(header_highlights) do
        diff_highlights[#diff_highlights + 1] = hl
      end
    elseif diff_type == 'add' then
      diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitSignsAddLn', line = true }
    elseif diff_type == 'remove' then
      diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitSignsDeleteLn', line = true }
    else
      diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitPatchContext', line = true }
    end
  end

  return diff_highlights
end

function PatchHighlighter:get_diff_line_highlights_with_metadata(lines, line_metadata)
  local diff_highlights = {}

  for i, line in ipairs(lines) do
    local meta = line_metadata[i]
    local row = i - 1

    if meta then
      if meta.type == 'separator' then
        diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitPatchSeparator', line = true }
      elseif meta.type == 'filename' then
        diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitPatchFileHeader', line = true }
      elseif meta.type == 'code' then
        local diff_type = get_line_diff_type(line, meta)

        if diff_type == 'header' then
          local header_highlights = self:get_hunk_header_highlights(line, row)
          for _, hl in ipairs(header_highlights) do
            diff_highlights[#diff_highlights + 1] = hl
          end
        elseif diff_type == 'add' then
          diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitSignsAddLn', line = true }
        elseif diff_type == 'remove' then
          diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitSignsDeleteLn', line = true }
        else
          diff_highlights[#diff_highlights + 1] = { row = row, hl_group = 'GitPatchContext', line = true }
        end
      end
    end
  end

  return diff_highlights
end

-- Parse hunk header "@@ -1,3 +1,5 @@" to extract start line numbers
function PatchHighlighter:parse_hunk_header(header)
  if not header then
    return 1, 1
  end

  local orig_start, curr_start = header:match('@@ %-(%d+),?%d* %+(%d+),?%d* @@')
  if not orig_start then
    -- Try without count
    orig_start, curr_start = header:match('@@ %-(%d+) %+(%d+) @@')
  end

  return tonumber(orig_start) or 1, tonumber(curr_start) or 1
end

-- Build a lookup map: line_number -> list of highlights for that line
function PatchHighlighter:build_line_highlight_map(highlights)
  local map = {}

  for _, hl in ipairs(highlights) do
    local line = hl.row + 1  -- Convert to 1-indexed
    if not map[line] then
      map[line] = {}
    end
    map[line][#map[line] + 1] = {
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    }
  end

  return map
end

-- Map highlights from source file line to target patch row with column offset
function PatchHighlighter:map_line_highlights(result, hl_map, source_line, target_row, col_offset)
  local line_hls = hl_map[source_line]
  if not line_hls then
    return
  end

  for _, hl in ipairs(line_hls) do
    result[#result + 1] = {
      row = target_row,
      col_start = hl.col_start + col_offset,
      col_end = hl.col_end > 0 and (hl.col_end + col_offset) or -1,
      hl_group = hl.hl_group,
    }
  end
end

-- Highlight using full file content for accurate TreeSitter parsing
-- params = {
--   original_lines = {...},  -- Full original file lines
--   current_lines = {...},   -- Full current file lines
--   filetype = 'lua',
--   hunks = { { header = '@@...', diff = {...}, patch_start_row = N }, ... }
--   strip_prefix = false,    -- If true, content has +/- prefix stripped (use col_offset=0)
-- }
function PatchHighlighter:highlight_from_full_files(params)
  if not params then
    return {}
  end

  local original_lines = params.original_lines or {}
  local current_lines = params.current_lines or {}
  local filetype = params.filetype
  local hunks = params.hunks or {}
  local strip_prefix = params.strip_prefix or false
  local col_offset = strip_prefix and 0 or 1

  if not filetype or filetype == '' or filetype == 'text' then
    return {}
  end

  if #hunks == 0 then
    return {}
  end

  local all_highlights = {}

  -- Create scratch buffer with FULL original file and get TreeSitter highlights
  local orig_hl_map = {}
  if #original_lines > 0 then
    local orig_bufnr = self:create_scratch_buffer(original_lines, filetype)
    local orig_highlights = self:get_treesitter_highlights(orig_bufnr, filetype)
    orig_hl_map = self:build_line_highlight_map(orig_highlights)

    vim.schedule(function()
      pcall(vim.api.nvim_buf_delete, orig_bufnr, { force = true })
    end)
  end

  -- Create scratch buffer with FULL current file and get TreeSitter highlights
  local curr_hl_map = {}
  if #current_lines > 0 then
    local curr_bufnr = self:create_scratch_buffer(current_lines, filetype)
    local curr_highlights = self:get_treesitter_highlights(curr_bufnr, filetype)
    curr_hl_map = self:build_line_highlight_map(curr_highlights)

    vim.schedule(function()
      pcall(vim.api.nvim_buf_delete, curr_bufnr, { force = true })
    end)
  end

  -- For each hunk, map highlights to patch lines
  for _, hunk in ipairs(hunks) do
    local orig_lnum, curr_lnum = self:parse_hunk_header(hunk.header)
    local patch_row = hunk.patch_start_row or 0

    -- Skip the header line itself
    if hunk.header then
      patch_row = patch_row + 1
    end

    for _, diff_line in ipairs(hunk.diff or {}) do
      local prefix = diff_line:sub(1, 1)

      if prefix == '-' then
        -- Removed line - use highlights from original file
        self:map_line_highlights(all_highlights, orig_hl_map, orig_lnum, patch_row, col_offset)
        orig_lnum = orig_lnum + 1
      elseif prefix == '+' then
        -- Added line - use highlights from current file
        self:map_line_highlights(all_highlights, curr_hl_map, curr_lnum, patch_row, col_offset)
        curr_lnum = curr_lnum + 1
      else
        -- Context line - use current file (same content in both)
        self:map_line_highlights(all_highlights, curr_hl_map, curr_lnum, patch_row, col_offset)
        orig_lnum = orig_lnum + 1
        curr_lnum = curr_lnum + 1
      end

      patch_row = patch_row + 1
    end
  end

  return all_highlights
end

return PatchHighlighter
