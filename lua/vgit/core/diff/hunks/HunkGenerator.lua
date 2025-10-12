local Object = require('vgit.core.Object')

local HunkGenerator = Object:extend()

function HunkGenerator:generate(original_lines, current_lines, opts)
  error('Must implement generate(original_lines, current_lines, opts)')
end

return HunkGenerator
