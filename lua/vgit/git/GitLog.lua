local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local GitLog = Object:extend()

function GitLog:constructor(line, revision_count)
  local log = vim.split(line, '\x1F')
  local parents = vim.split(log[2], ' ')
  local revision = revision_count and string.format('HEAD~%s', revision_count)

  if #parents > 1 then log[2] = parents[1] end

  return {
    id = utils.math.uuid(),
    revision = revision,
    commit_hash = log[1]:sub(2, #log[1]),
    parent_hash = log[2],
    timestamp = log[3],
    author_name = log[4],
    author_email = log[5],
    summary = log[6]:sub(1, #log[6] - 1),
  }
end

function GitLog:age()
  return utils.date.age(self.timestamp)
end

return GitLog
