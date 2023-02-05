local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')

local Notification = Object:extend()

function Notification:constructor()
  return {
    timer_id = nil,
  }
end

function Notification:clear_timer()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end

  return self
end

function Notification:clear_notification(source)
  self:clear_timer()
  source:clear_notification()

  return self
end

function Notification:notify(source, text)
  local epoch = 2000

  self:clear_timer()
  source:trigger_notification(text)
  self.timer_id = vim.fn.timer_start(
    epoch,
    loop.coroutine(function()
      source:clear_notification()
      self:clear_timer()
    end)
  )

  return self
end

return Notification
