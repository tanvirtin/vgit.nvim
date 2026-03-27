local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')

local GitPatch = Object:extend()

function GitPatch:constructor(filename, hunk)
  local header = hunk.header

  -- Generate header if hunk doesn't have one
  if not header then
    -- Default: 1 line added at the end
    header = string.format('@@ -1,0 +1,%d @@', #hunk.diff)
  elseif hunk.type == 'add' then
    local previous, _ = hunk:parse_header(header)
    header = string.format('@@ -%s,%s +%s,%s @@', previous[1], previous[2], previous[1] + 1, #hunk.diff)
  end

  local patch = {
    string.format('diff --git a/%s b/%s', filename, filename),
    'index 000000..000000',
    string.format('--- a/%s', filename),
    string.format('+++ b/%s', filename),
    header,
  }

  for i = 1, #hunk.diff do
    patch[#patch + 1] = hunk.diff[i]
  end

  return patch
end

return GitPatch
