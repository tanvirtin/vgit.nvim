local Object = require('vgit.core.Object')

local CodeDTO = Object:extend()

function CodeDTO:new(opts)
  opts = opts or {}
  return setmetatable({
    lines = opts.lines or {},
    current_lines = opts.current_lines or {},
    previous_lines = opts.previous_lines or {},
    lnum_changes = opts.lnum_changes or {},
    hunks = opts.hunks or {},
    marks = opts.marks or {},
    stat = opts.stat or {
      added = 0,
      removed = 0,
    },
  }, CodeDTO)
end

return CodeDTO
