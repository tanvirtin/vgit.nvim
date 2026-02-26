local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local signs_setting = lazy('vgit.settings.signs')

local DiffAnnotator = Object:extend()

local _scene_signs

local function get_scene_signs()
  if not _scene_signs then _scene_signs = signs_setting:get('usage').scene end
  return _scene_signs
end

function DiffAnnotator:constructor()
  return {}
end

function DiffAnnotator:annotate_line(line_changes)
  local lnum_change = line_changes.lnum_change
  if not lnum_change then return nil end

  local lnum = lnum_change.lnum
  local change_type = lnum_change.type
  local sign_name = get_scene_signs()[change_type]

  local marks = {}

  if sign_name then marks.sign = {
    col = lnum - 1,
    name = sign_name,
  } end

  if change_type == 'void' then marks.void_text = {
    row = lnum - 1,
    col = 0,
    hl = 'GitLineNr',
  } end

  return marks
end

function DiffAnnotator:annotate_word(line_changes, lnum)
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

return DiffAnnotator
