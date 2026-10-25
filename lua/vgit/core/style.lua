local style = {}

local function header_highlights(line, row)
  local highlights = {
    { row = row, role = 'header', line = true },
    { row = row, col_start = 0, col_end = 2, role = 'header_marker' },
  }

  local minus_start, minus_end = line:find('%-[%d,]+')
  if minus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = minus_start - 1,
      col_end = minus_end,
      role = 'header_remove',
    }
  end

  local plus_start, plus_end = line:find('%+[%d,]+')
  if plus_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = plus_start - 1,
      col_end = plus_end,
      role = 'header_add',
    }
  end

  local close_start = line:find(' @@', plus_end or minus_end or 2)
  if close_start then
    highlights[#highlights + 1] = {
      row = row,
      col_start = close_start,
      col_end = close_start + 2,
      role = 'header_marker',
    }
  end

  return highlights
end

style.header = header_highlights

local function add_line(result, line, meta, row)
  if not meta then return end

  if meta.type == 'separator' then
    result[#result + 1] = { row = row, role = 'separator', line = true }
    return
  end

  if meta.type == 'filename' then
    result[#result + 1] = { row = row, role = 'filename', line = true }
    return
  end

  if meta.type ~= 'code' then return end

  if meta.is_header then
    for _, hl in ipairs(header_highlights(line, row)) do
      result[#result + 1] = hl
    end
    return
  end

  local change_type = meta.lnum_change and meta.lnum_change.type

  if change_type == 'void' then return end

  result[#result + 1] = {
    row = row,
    role = change_type or 'context',
    line = true,
  }
end

function style.annotate(lines, line_metadata)
  local result = {}

  for i, line in ipairs(lines) do
    add_line(result, line, line_metadata[i], i - 1)
  end

  return result
end

return style
