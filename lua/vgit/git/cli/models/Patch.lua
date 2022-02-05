local Object = require('vgit.core.Object')
local utils = require('vgit.core.utils')

local Patch = Object:extend()

function Patch:constructor(filename, hunk)
  local header = hunk.header

  if hunk.type == 'add' then
    local previous, current = hunk:parse_header(header)
    header = string.format(
      '@@ -%s,%s +%s,%s @@',
      previous[1],
      0,
      previous[1] + 1,
      current[2]
    )
  end

  local patch = {
    id = utils.math.uuid(),
    string.format('diff --git a/%s b/%s', filename, filename),
    'index 000000..000000',
    string.format('--- a/%s', filename),
    string.format('+++ a/%s', filename),
    header,
  }

  for i = 1, #hunk.diff do
    patch[#patch + 1] = hunk.diff[i]
  end

  return patch
end

return Patch
