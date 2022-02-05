local Object = require('vgit.core.Object')

local CodeDTO = Object:extend()

-- NOTE: VGit ui will paint using what can be found inside of this.
-- Eventually we can pass this object as an RPC, using a more performant backend.
-- That's all it should take to keep existing functionalities in place while the core engine gets replaced.
-- Files such as Diff.lua, Git.lua, and all git modeling can be completed removed and not handled by lua.
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
