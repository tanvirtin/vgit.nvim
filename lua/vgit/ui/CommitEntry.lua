local Object = require('vgit.core.Object')

local CommitEntry = Object:extend()

function CommitEntry:new(log, files)
  return setmetatable({
    log = log,
    files = files,
  }, CommitEntry)
end

return CommitEntry
