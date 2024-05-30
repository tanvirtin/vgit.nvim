local Object = require('vgit.core.Object')

local NavigationVirtualText = Object:extend()

function NavigationVirtualText:constructor()
  return {
    timer_id = nil,
    epoch = 1000,
  }
end

function NavigationVirtualText:clear_timer()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end
end

function NavigationVirtualText:place(buffer, window, text)
  self:unplace(buffer)
  buffer:transpose_virtual_text({
    text = text,
    hl = 'GitComment',
    row = window:get_lnum() - 1,
    col = 0,
    pos = 'right_align'
  })
  self.timer_id = vim.fn.timer_start(self.epoch, function()
    if buffer:is_valid() then
      buffer:clear_namespace()
    end
    self:clear_timer()
  end)
end

function NavigationVirtualText:unplace(buffer)
  self:clear_timer()
  if buffer:is_valid() then
    buffer:clear_namespace()
  end
end

return NavigationVirtualText
