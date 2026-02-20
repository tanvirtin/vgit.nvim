local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local DiffStyleAnnotator = Object:extend()

function DiffStyleAnnotator:constructor()
  return {}
end

function DiffStyleAnnotator:_annotate_header(line, row)
  local highlights = {}

  highlights[#highlights + 1] = {
    row = row,
    hl_group = 'GitPatchHeader',
    line = true,
  }

  highlights[#highlights + 1] = {
    row = row,
    col_start = 0,
    col_end = 2,
    hl_group = 'GitPatchHeaderMarker',
  }

  local minus_start, minus_end = line:find('%-[%d,]+')
  if minus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = minus_start - 1,
      col_end = minus_end,
      hl_group = 'GitPatchHeaderRemove',
    }
  end

  local plus_start, plus_end = line:find('%+[%d,]+')
  if plus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = plus_start - 1,
      col_end = plus_end,
      hl_group = 'GitPatchHeaderAdd',
    }
  end

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

function DiffStyleAnnotator:_annotate_line(result, line, meta, row)
  if not meta then return end

  if meta.type == 'separator' then
    result[#result + 1] = { row = row, hl_group = 'GitPatchSeparator', line = true }
    return
  end

  if meta.type == 'filename' then
    result[#result + 1] = { row = row, hl_group = 'GitPatchFileHeader', line = true }
    return
  end

  if meta.type ~= 'code' then return end

  local change_type = meta.lnum_change and meta.lnum_change.type

  if meta.is_header then
    local header_highlights = self:_annotate_header(line, row)
    for _, hl in ipairs(header_highlights) do
      result[#result + 1] = hl
    end
  elseif change_type == 'add' then
    result[#result + 1] = { row = row, hl_group = 'GitSignsAddLn', line = true }
  elseif change_type == 'remove' then
    result[#result + 1] = { row = row, hl_group = 'GitSignsDeleteLn', line = true }
  else
    result[#result + 1] = { row = row, hl_group = 'GitPatchContext', line = true }
  end
end

function DiffStyleAnnotator:annotate(lines, line_metadata)
  local diff_highlights = {}

  for i, line in ipairs(lines) do
    self:_annotate_line(diff_highlights, line, line_metadata[i], i - 1)
  end

  return diff_highlights
end

return DiffStyleAnnotator
