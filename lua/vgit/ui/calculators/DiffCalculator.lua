local Object = require('vgit.core.Object')

local DiffCalculator = Object:extend()

function DiffCalculator:calculate_line_diff_marks(line_changes)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local signs_setting = require('vgit.settings.signs')
  local line_number_hl = 'GitLineNr'
  local signs_usage_setting = signs_setting:get('usage')
  local scene_signs = signs_usage_setting.scene
  local main_signs = signs_usage_setting.main

  local lnum = lnum_change.lnum
  local change_type = lnum_change.type
  local sign_name = scene_signs[change_type]

  if change_type ~= 'void' then line_number_hl = main_signs[change_type] end

  local marks = {}

  if sign_name then marks.sign = {
    col = lnum - 1,
    name = sign_name,
  } end

  if change_type == 'void' then marks.void_text = {
    row = lnum - 1,
    col = 0,
    hl = line_number_hl,
  } end

  return marks
end

function DiffCalculator:calculate_word_diff_marks(line_changes, lnum)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local word_diff = lnum_change.word_diff
  if not word_diff then return nil end

  local texts = {}
  local change_type = lnum_change.type

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

  return {
    texts = texts,
    col = 0,
    row = lnum - 1,
  }
end

return DiffCalculator
