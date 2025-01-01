local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.git.git_repo')

local Model = Object:extend()

function Model:constructor()
  return {
    state = { logs = nil },
  }
end

function Model:reset()
  self.state = { logs = nil }
end

function Model:get_title()
  return 'Git Stash'
end

function Model:fetch(opts)
  opts = opts or {}

  self:reset()

  local reponame = git_repo.discover()
  local logs, err = git_log.list_stash(reponame)
  if err then return nil, err end

  self.state.logs = logs

  return logs, err
end

function Model:get_logs()
  return self.state.logs
end

function Model:get_lines()
  if not self.state.logs then return end

  local lines = {}
  for log in ipairs(self.state.logs) do
    lines[#lines + 1] = string.format('%s %s', log.commit_hash, log.summary)
  end

  return lines
end

return Model
