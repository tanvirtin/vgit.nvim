local lazy = require('vgit.core.lazy')

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

function DiffAnnotator.word_diff_to_texts(word_diff, change_type)
  local texts = {}
  for j = 1, #word_diff do
    local segment = word_diff[j]
    local operation, fragment = unpack(segment)
    if operation == -1 then
      local hl = change_type == 'remove' and 'GitWordDelete' or 'GitWordAdd'
      texts[#texts + 1] = { fragment, hl }
    elseif operation == 0 then
      texts[#texts + 1] = { fragment, nil }
    end
  end
  return texts
end

function DiffAnnotator.annotate_word(line_changes, lnum)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local word_diff = lnum_change.word_diff
  if not word_diff then return nil end

  return {
    texts = DiffAnnotator.word_diff_to_texts(word_diff, lnum_change.type),
    col = 0,
    row = lnum - 1,
  }
end

return DiffAnnotator
