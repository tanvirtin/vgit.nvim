local Object = require('vgit.core.Object')

local Conflict = Object:extend()

function Conflict:constructor()
  return {
    markers = {
      start = '<<<<<<<',
      middle = '=======',
      finish = '>>>>>>>',
      ancestor = '|||||||',
    },
  }
end

function Conflict:match_line(line, marker) return line:match(string.format('^%s', marker)) end

function Conflict:parse(lines)
  local conflicts = {}

  local conflict = nil
  local has_start = false
  local has_middle = false
  local has_ancestor = false

  for lnum, line in ipairs(lines) do
    if self:match_line(line, self.markers.start) then
      has_start = true

      conflict = {
        current = { start = lnum },
        middle = {},
        incoming = {},
        ancestor = {},
      }
    end

    if has_start and self:match_line(line, self.markers.ancestor) then
      has_ancestor = true

      conflict.ancestor.start = lnum
      conflict.current.finish = lnum - 1
    end

    if has_start and self:match_line(line, self.markers.middle) then
      has_middle = true

      if has_ancestor then
        conflict.ancestor.finish = lnum - 1
      else
        conflict.current.finish = lnum - 1
      end

      conflict.middle.start = lnum
      conflict.middle.finish = lnum + 1
      conflict.incoming.start = lnum + 1
    end

    if has_start and has_middle and self:match_line(line, self.markers.finish) then
      conflict.incoming.finish = lnum

      conflicts[#conflicts + 1] = conflict

      conflict = nil
      has_start = false
      has_middle = false
      has_ancestor = false
    end
  end

  return conflicts
end

return Conflict
