local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')
local signs_setting = lazy('vgit.settings.signs')

local DiffCalculator = Object:extend()

-- Cache sign usage settings at module level — these never change after setup
local _scene_signs
local _main_signs

local function get_scene_signs()
  if not _scene_signs then
    local usage = signs_setting:get('usage')
    _scene_signs = usage.scene
    _main_signs = usage.main
  end
  return _scene_signs, _main_signs
end

function DiffCalculator:calculate_line_diff_marks(line_changes)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local line_number_hl = 'GitLineNr'
  local scene_signs, main_signs = get_scene_signs()

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
