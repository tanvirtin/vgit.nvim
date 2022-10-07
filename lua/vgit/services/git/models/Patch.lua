local Object = require('vgit.core.Object')

local Patch = Object:extend()

function Patch:constructor(filename, hunk)
  local header = hunk.header

  if hunk.type == 'add' then
    local previous, _ = hunk:parse_header(header)
    -- NOTE: Header indicates metadata of the change between the two version of a file.
    --       @@ -3, 0, +4, 5 @@ means in the previous file changes start at line 3 and
    --       there are 0 additions. In the current file changes start at line 4 with 5
    --       new line additions.
    header = string.format('@@ -%s,%s +%s,%s @@', previous[1], previous[2], previous[1] + 1, #hunk.diff)
  end

  local patch = {
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
