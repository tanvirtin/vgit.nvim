local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local git_log = require('vgit.git.git_log')
local git_repo = require('vgit.libgit2.git_repo')

local Model = Object:extend()

function Model:constructor()
  return {
    state = {
      logs = nil,
      selected = {
        set = {},
        ordered = {},
      },
      pagination = {
        count = nil,
        skip = nil,
        display = nil,
      },
    },
  }
end

function Model:reset()
  self.state = {
    logs = nil,
    selected = {
      set = {},
      ordered = {},
    },
    pagination = {
      count = nil,
      skip = nil,
      display = nil,
    },
  }
end

function Model:select(log)
  if self:is_selected(log) then
    self.state.selected.set[log.commit_hash] = nil
    for i = 1, #self.state.selected.ordered do
      local selected_log = self.state.selected.ordered[i]
      if selected_log.commit_hash == log.commit_hash then self.state.selected.ordered[i] = nil end
    end
    return
  end
  self.state.selected.set[log.commit_hash] = true
  self.state.selected.ordered[#self.state.selected.ordered + 1] = log
end

function Model:get_selected()
  return self.state.selected.ordered
end

function Model:is_selected(log)
  return self.state.selected.set[log.commit_hash] ~= nil
end

function Model:fetch()
  self:reset()

  local reponame = git_repo.discover()
  local pagination = {
    skip = 0,
    count = 100,
    display = string.format('%s-%s', 1, 100),
  }
  local logs, err = git_log.list(reponame, { pagination = pagination })
  if err then return nil, err end

  self.state.logs = utils.list.map(logs, function(log)
    log.timestamp = log:date()
    return log
  end)
  self.state.pagination = pagination

  return logs
end

function Model:get_pagination()
  return self.state.pagination
end

function Model:get_logs()
  return self.state.logs
end

function Model:next()
  local reponame = git_repo.discover()
  local count = 100
  local skip = self.state.pagination.count + self.state.pagination.skip
  local pagination = {
    count = count,
    skip = skip,
    display = nil,
  }
  local logs, err = git_log.list(reponame, { pagination = pagination })
  if err then return nil, err end
  if #logs == 0 then return end

  pagination.display = string.format('%s-%s', skip + 1, skip + #logs)

  self.state.pagination = pagination
  self.state.logs = utils.list.map(logs, function(log)
    log.timestamp = log:date()
    return log
  end)

  return logs
end

function Model:previous()
  if self.state.pagination.skip == 0 then return end

  local reponame = git_repo.discover()
  local count = 100
  local skip = self.state.pagination.skip - self.state.pagination.count
  local pagination = {
    count = count,
    skip = skip,
    display = nil,
  }
  local logs, err = git_log.list(reponame, { pagination = pagination })
  if err then return nil, err end

  pagination.display = string.format('%s-%s', skip + 1, skip + #logs)

  self.state.pagination = pagination
  self.state.logs = utils.list.map(logs, function(log)
    log.timestamp = log:date()
    return log
  end)

  return logs
end

return Model
