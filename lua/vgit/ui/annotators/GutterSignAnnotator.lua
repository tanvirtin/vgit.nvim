local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local GutterSignAnnotator = Object:extend()

function GutterSignAnnotator:constructor()
  return {}
end

function GutterSignAnnotator:annotate(hunks, sign_types)
  local signs = {}
  local signs_len = 0
  for i = 1, #hunks do
    local hunk = hunks[i]
    local hunk_type = hunk.type
    local sign_name = sign_types[hunk_type]
    for j = hunk.top, hunk.bot do
      local lnum = (hunk_type == 'remove' and j == 0) and 1 or j
      signs_len = signs_len + 1
      signs[signs_len] = {
        col = lnum - 1,
        name = sign_name,
      }
    end
  end
  return signs
end

return GutterSignAnnotator
