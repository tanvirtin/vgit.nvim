local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

local Query = Object:extend()

function Query:constructor()
  return {
    err = nil,
    data = nil,
  }
end

function Query:reset()
  self.err = nil
  self.data = nil

  return self
end

function Query:fetch(options)
  self:reset()

  local err, logs = Git():logs(options, { is_background = true })

  if err then
    return err, nil
  end

  self.err = nil

  self.data = logs

  return self.err, self.data
end

function Query:get_data()
  return self.err, self.data
end

return Query
