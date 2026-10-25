local lazy = require('vgit.core.lazy')

local Diff = lazy('vgit.core.diff.Diff')

local words = {}

local WORD_ROLE = { remove = 'word_delete', add = 'word_add' }

function words.ranges(word_diff, change_type)
  local ranges = {}
  local role = WORD_ROLE[change_type] or 'word_add'
  local col = 0

  for j = 1, #word_diff do
    local operation, fragment = unpack(word_diff[j])

    if operation == -1 then
      ranges[#ranges + 1] = { col_start = col, col_end = col + #fragment, role = role }
      col = col + #fragment
    elseif operation == 0 then
      col = col + #fragment
    end
  end

  return ranges
end

function words.overlay(line, ranges)
  if not line or #ranges == 0 then return nil end

  local texts = {}
  local col = ranges[1].col_start

  for _, range in ipairs(ranges) do
    if range.col_start > col then texts[#texts + 1] = { line:sub(col + 1, range.col_start), nil } end

    texts[#texts + 1] = { line:sub(range.col_start + 1, range.col_end), range.role or range.hl_group }
    col = range.col_end
  end

  return { col = ranges[1].col_start, texts = texts }
end

function words.ranges_for(lnum_change)
  local word_diff = lnum_change and Diff.word_diff(lnum_change)
  if not word_diff then return nil end

  return words.ranges(word_diff, lnum_change.type)
end

function words.overlay_for(lnum_change, line)
  local ranges = words.ranges_for(lnum_change)
  if not ranges then return nil end

  return words.overlay(line, ranges)
end

function words.overlays(lines, line_metadata)
  local result = {}

  for i, meta in ipairs(line_metadata) do
    local overlay = words.overlay_for(meta and meta.lnum_change, lines[i])

    if overlay then result[#result + 1] = { row = i - 1, col = overlay.col, texts = overlay.texts } end
  end

  return result
end

return words
