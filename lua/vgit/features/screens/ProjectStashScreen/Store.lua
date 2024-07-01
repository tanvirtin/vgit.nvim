local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.git.git_repo')

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
  local logs, err = git_log.list_stash(reponame)
  if err then return nil, err end

  self.err = nil
  self.data = logs

  return self.data, self.err
end

function Store:get_logs()
  return self.data, self.err
end

function Store:get_lines()
  if self.err then return nil, self.err end

  local data = {}
  for i = 1, #self.data do
    local log = self.data[i]
    data[#data + 1] = string.format('%s %s', log.commit_hash, log.summary)
  end

  return data
end

function Store:get_title()
  return 'Git Stash'
end

return Store
