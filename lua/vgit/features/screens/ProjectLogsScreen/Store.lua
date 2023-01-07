local Git = require('vgit.git.cli.Git')
local Object = require('vgit.core.Object')

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

function Store:fetch(args, opts)
  opts = opts or {}

  self:reset()

  local err, logs = Git():logs(args, { is_background = true })

  if err then
    return err, nil
  end

  self.err = nil

  self.data = logs

  return self.err, self.data
end

function Store:get_data() return self.err, self.data end

return Store
