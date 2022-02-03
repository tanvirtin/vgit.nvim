local Object = require('vgit.core.Object')

local FileEntry = Object:extend()

function FileEntry:new(file, type)
  return setmetatable({
    file = file,
    type = type,
  }, FileEntry)
end

return FileEntry
