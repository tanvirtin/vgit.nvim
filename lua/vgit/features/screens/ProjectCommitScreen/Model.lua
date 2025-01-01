local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local git_commit = require('vgit.git.git_commit')

local Model = Object:extend()

function Model:constructor()
  return {
    err = nil,
    data = nil,
  }
end

function Model:reset()
  self.err = nil
  self.data = nil
end

function Model:fetch(opts)
  opts = opts or {}

  self:reset()

  local reponame = git_repo.discover()
  self.data, self.err = git_commit.dry_run(reponame)

  return self.data, self.err
end

function Model:get_lines()
  if self.err then return nil, self.err end

  return utils.list.concat(
    { '' },
    utils.list.map(self.data, function(line)
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
