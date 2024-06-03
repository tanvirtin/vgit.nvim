local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local git_commit = require('vgit.git.git_commit')

local Mutation = Object:extend()

function Mutation:commit(lines)
  local description = utils.list.reduce(lines, '', function(acc, line)
    if not vim.startswith(line, '#') then acc = acc .. line .. '\n' end

    return acc
  end)

  local reponame = git_repo.discover()
  return git_commit.create(reponame, description)
end

return Mutation
