local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_repo = require('vgit.git.git_repo')
local git_commit = require('vgit.git.git_commit')

local Store = Object:extend()

function Store:constructor()
  return {
    err = nil,
    data = nil,
  }
end

function Store:reset()
  self.err = nil
  self.data = nil
end

function Store:fetch(opts)
  opts = opts or {}

  self:reset()

  local reponame = git_repo.discover()
  self.data, self.err = git_commit.dry_run(reponame)

  return self.data, self.err
end

function Store:get_lines()
  if self.err then return nil, self.err end

  return utils.list.concat(
      { '' },
      utils.list.map(self.data, function(line)
        return '# ' .. line
      end)
    )
end

return Store
