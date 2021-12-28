local Object = require('vgit.core.Object')

local Marker = Object:extend()

function Marker:new()
  return setmetatable({
    timer_id = nil,
    epoch = 1000,
  }, Marker)
end

function Marker:clear_timer()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end
end

function Marker:mark_current_hunk(buffer, window, text)
  self:unmark_current_hunk(buffer)
  self:clear_timer()
  buffer:transpose_virtual_text(
    text,
    'GitComment',
    window:get_lnum() - 1,
    0,
    'right_align'
  )
  self.timer_id = vim.fn.timer_start(self.epoch, function()
    if buffer:is_valid() then
      buffer:clear_namespace()
    end
    self:clear_timer()
  end)
end

function Marker:unmark_current_hunk(buffer)
  self:clear_timer()
  if buffer:is_valid() then
    buffer:clear_namespace()
  end
end

return Marker
