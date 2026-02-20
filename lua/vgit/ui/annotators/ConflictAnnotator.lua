local lazy = require('vgit.core.lazy')
local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')

local ConflictAnnotator = Object:extend()

function ConflictAnnotator:constructor()
  return {}
end

function ConflictAnnotator:annotate(conflict)
  local current = conflict.current
  local ancestor = conflict.ancestor
  local middle = conflict.middle
  local incoming = conflict.incoming

  local signs = {}
  local texts = {}

  signs[#signs + 1] = {
    col = current.top - 1,
    name = 'GitConflictCurrentMark',
  }
  texts[#texts + 1] = {
    text = '(Current Change)',
    hl = 'GitComment',
    row = current.top - 1,
    col = 0,
    pos = 'eol',
  }

  for lnum = current.top + 1, current.bot do
    signs[#signs + 1] = {
      col = lnum - 1,
      name = 'GitConflictCurrent',
    }
  end

  if ancestor and not utils.list.is_empty(ancestor) then
    signs[#signs + 1] = {
      col = ancestor.top - 1,
      name = 'GitConflictAncestorMark',
    }
    for lnum = ancestor.top + 1, ancestor.bot do
      signs[#signs + 1] = {
        col = lnum - 1,
        name = 'GitConflictAncestor',
      }
    end
  end

  for lnum = middle.top, middle.bot do
    signs[#signs + 1] = {
      col = lnum - 1,
      name = 'GitConflictMiddle',
    }
  end

  for lnum = incoming.top, incoming.bot - 1 do
    signs[#signs + 1] = {
      col = lnum - 1,
      name = 'GitConflictIncoming',
    }
  end

  signs[#signs + 1] = {
    col = incoming.bot - 1,
    name = 'GitConflictIncomingMark',
  }

  texts[#texts + 1] = {
    text = '(Incoming Change)',
    hl = 'GitComment',
    row = incoming.bot - 1,
    col = 0,
    pos = 'eol',
  }

  return { signs = signs, texts = texts }
end

return ConflictAnnotator
