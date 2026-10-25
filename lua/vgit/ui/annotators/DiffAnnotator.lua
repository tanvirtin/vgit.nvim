local lazy = require('vgit.core.lazy')

local Diff = lazy('vgit.core.diff.Diff')
local core_words = lazy('vgit.core.words')
local signs_setting = lazy('vgit.settings.signs')

local DiffAnnotator = {}

local WORD_GROUPS = { word_add = 'GitWordAdd', word_delete = 'GitWordDelete' }

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

function DiffAnnotator.word_ranges(word_diff, change_type)
  local mapped = {}

  for _, range in ipairs(core_words.ranges(word_diff, change_type)) do
    mapped[#mapped + 1] = {
      col_start = range.col_start,
      col_end = range.col_end,
      hl_group = WORD_GROUPS[range.role],
    }
  end

  return mapped
end

function DiffAnnotator.word_overlay(line, ranges)
  return core_words.overlay(line, ranges)
end

function DiffAnnotator.word_ranges_for(lnum_change)
  local word_diff = lnum_change and Diff.word_diff(lnum_change)
  if not word_diff then return nil end

  return DiffAnnotator.word_ranges(word_diff, lnum_change.type)
end

function DiffAnnotator.annotate_word(line_changes, lnum)
  local ranges = DiffAnnotator.word_ranges_for(line_changes.lnum_change)
  if not ranges then return nil end

  return { ranges = ranges, row = lnum - 1 }
end

function DiffAnnotator.word_overlay_for(lnum_change, line)
  local ranges = DiffAnnotator.word_ranges_for(lnum_change)
  if not ranges then return nil end

  return DiffAnnotator.word_overlay(line, ranges)
end

return DiffAnnotator
