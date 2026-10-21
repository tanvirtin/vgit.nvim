local lazy = require('vgit.core.lazy')

local Diff = lazy('vgit.core.diff.Diff')
local signs_setting = lazy('vgit.settings.signs')

local DiffAnnotator = {}

function DiffAnnotator.annotate_line(line_changes)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return {} end

  local lnum = lnum_change.lnum
  local change_type = lnum_change.type
  local sign_name = signs_setting:get('usage').scene[change_type]

  local marks = {}

  if sign_name then marks.sign = {
    row = lnum - 1,
    name = sign_name,
  } end

  if change_type == 'void' then marks.void_text = {
    row = lnum - 1,
    col = 0,
    hl = 'GitLineNr',
  } end

  return marks
end

DiffAnnotator.WORD_PRIORITY = 150

function DiffAnnotator.word_ranges(word_diff, change_type)
  local ranges = {}
  local hl = change_type == 'remove' and 'GitWordDelete' or 'GitWordAdd'
  local col = 0

  for j = 1, #word_diff do
    local operation, fragment = unpack(word_diff[j])

    if operation == -1 then
      ranges[#ranges + 1] = { col_start = col, col_end = col + #fragment, hl_group = hl }
      col = col + #fragment
    elseif operation == 0 then
      col = col + #fragment
    end
  end

  return ranges
end

function DiffAnnotator.word_overlay(line, ranges)
  if not line or #ranges == 0 then return nil end

  local texts = {}
  local col = ranges[1].col_start

  for _, range in ipairs(ranges) do
    if range.col_start > col then texts[#texts + 1] = { line:sub(col + 1, range.col_start), nil } end

    texts[#texts + 1] = { line:sub(range.col_start + 1, range.col_end), range.hl_group }
    col = range.col_end
  end

  return { col = ranges[1].col_start, texts = texts }
end

function DiffAnnotator.annotate_word(line_changes, lnum)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local word_diff = Diff.word_diff(lnum_change)
  if not word_diff then return nil end

  return {
    ranges = DiffAnnotator.word_ranges(word_diff, lnum_change.type),
    row = lnum - 1,
  }
end

return DiffAnnotator
