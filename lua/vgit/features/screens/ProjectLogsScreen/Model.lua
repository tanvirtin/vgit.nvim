local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.git.git_repo')

local Model = Object:extend()

function Model:constructor()
  return {
    state = { logs = nil }
  }
end

function Model:reset()
  self.state = { logs = nil }
end

function Model:fetch()
  self:reset()

  local reponame = git_repo.discover()
  local logs, err = git_log.list(reponame)
  if err then return nil, err end

  self.state.logs = logs

  return logs
end

function Model:get_logs()
  return self.state.logs
end

return Model
