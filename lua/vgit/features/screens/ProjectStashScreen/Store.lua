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

function Store:fetch(opts)
  opts = opts or {}

  self:reset()

  local err, logs = Git():ls_stash({ is_background = true })

  if err then
    return err, nil
  end

  self.err = nil

  self.data = logs

  return self.err, self.data
end

function Store:get_data() return self.err, self.data end

function Store:get_lines()
  if self.err then
    return self.err
  end

  local data = {}

  for i = 1, #self.data do
    local log = self.data[i]

    data[#data + 1] = string.format('%s %s', log.commit_hash, log.summary)
  end

  return nil, data
end

function Store:get_title() return nil, 'Git Stash' end

return Store
