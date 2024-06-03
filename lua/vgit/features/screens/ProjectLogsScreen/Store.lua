local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git2.log')
local git_repo = require('vgit.git.git2.repo')

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

  return self
end

function Store:fetch()
  self:reset()

  local reponame = git_repo.discover()
  local logs, err = git_log.list(reponame)
  if err then return err, nil end

  self.err = nil
  self.data = logs

  return self.err, self.data
end

function Store:get_data()
  return self.err, self.data
end

return Store
