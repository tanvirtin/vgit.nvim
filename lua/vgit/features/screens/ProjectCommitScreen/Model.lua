local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.libgit2.git_repo')
local git_commit = require('vgit.git.git_commit')

local Model = Object:extend()

function Model:constructor()
  return { state = { data = nil } }
end

function Model:reset()
  self.state = { data = nil }
end

function Model:fetch(opts)
  opts = opts or {}

  self:reset()

  local reponame = git_repo.discover()
  local data, err = git_commit.dry_run(reponame)

  self.state.data = data

  return data, err
end

function Model:get_lines()
  return utils.list.concat(
    { '' },
    utils.list.map(self.state.data, function(line)
      return '# ' .. line
    end)
  )
end

function Model:commit(lines)
  local description = utils.list.reduce(lines, '', function(acc, line)
    if not vim.startswith(line, '#') then acc = acc .. line .. '\n' end
    return acc
  end)

  local reponame = git_repo.discover()
  return git_commit.create(reponame, description)
end

return Model
