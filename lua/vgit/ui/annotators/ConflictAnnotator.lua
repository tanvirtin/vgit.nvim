local ConflictAnnotator = {}

local function add_signs_for_range(signs, top, bot, name)
  for lnum = top, bot do
    signs[#signs + 1] = { row = lnum - 1, name = name }
  end
end

function ConflictAnnotator.annotate(conflict)
  local current = conflict.current
  local ancestor = conflict.ancestor
  local middle = conflict.middle
  local incoming = conflict.incoming

  local signs = {}
  local texts = {}

  signs[#signs + 1] = { row = current.top - 1, name = 'GitConflictCurrentMark' }
  texts[#texts + 1] = { text = '(Current Change)', hl = 'GitComment', row = current.top - 1, col = 0, pos = 'eol' }
  add_signs_for_range(signs, current.top + 1, current.bot, 'GitConflictCurrent')

  if ancestor and ancestor.top then
    signs[#signs + 1] = { row = ancestor.top - 1, name = 'GitConflictAncestorMark' }
    add_signs_for_range(signs, ancestor.top + 1, ancestor.bot, 'GitConflictAncestor')
  end

  add_signs_for_range(signs, middle.top, middle.bot, 'GitConflictMiddle')
  add_signs_for_range(signs, incoming.top, incoming.bot - 1, 'GitConflictIncoming')

  signs[#signs + 1] = { row = incoming.bot - 1, name = 'GitConflictIncomingMark' }
  texts[#texts + 1] = { text = '(Incoming Change)', hl = 'GitComment', row = incoming.bot - 1, col = 0, pos = 'eol' }

  return { signs = signs, texts = texts }
end

return ConflictAnnotator
