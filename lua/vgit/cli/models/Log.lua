local Object = require('vgit.core.Object')

local Log = Object:extend()

function Log:new(line, revision_count)
  local log = vim.split(line, '-')
  -- Sometimes you can have multiple parents, in that instance we pick the first!
  local parents = vim.split(log[2], ' ')
  if #parents > 1 then
    log[2] = parents[1]
  end
  return setmetatable({
    revision = string.format('HEAD~%s', revision_count),
    commit_hash = log[1]:sub(2, #log[1]),
    parent_hash = log[2],
    timestamp = log[3],
    author_name = log[4],
    author_email = log[5],
    summary = log[6]:sub(1, #log[6] - 1),
  }, Log)
end

return Log
