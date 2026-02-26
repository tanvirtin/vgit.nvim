local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local BlameAnnotator = Object:extend()

function BlameAnnotator:constructor()
  return {}
end

function BlameAnnotator:annotate(blame, lnum, config, format_fn)
  local text = format_fn(blame, config)
  if type(text) ~= 'string' then return nil end
  return {
    text = text,
    hl = 'GitComment',
    row = lnum - 1,
    col = 0,
    pos = 'eol',
  }
end

return BlameAnnotator
