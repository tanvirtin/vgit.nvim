local Git = require('vgit.git.cli.Git')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Mutation = Object:extend()

function Mutation:constructor() return { git = Git() } end

function Mutation:commit(lines)
  local msg = utils.list.reduce(lines, '', function(acc, line)
    if not vim.startswith(line, '#') then
      acc = acc .. line .. '\n'
    end

    return acc
  end)

  return self.git:commit(msg)
end

return Mutation
