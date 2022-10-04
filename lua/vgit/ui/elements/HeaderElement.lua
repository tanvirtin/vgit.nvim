local Component = require('vgit.ui.Component')
local Namespace = require('vgit.core.Namespace')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local HeaderElement = Component:extend()

function HeaderElement:constructor(...) return Component.constructor(self, ...) end

function HeaderElement:get_height() return 1 end

function HeaderElement:trigger_notification(text)
  self.namespace:transpose_virtual_text(self.buffer, text, 'GitComment', 0, 0, 'eol')

  return self
end

function HeaderElement:clear_notification()
  if self.buffer:is_valid() then
    self.namespace:clear(self.buffer)
  end

  return self
end

function HeaderElement:mount(opts)
  local buffer = Buffer():create()
  self.buffer = buffer

  buffer:assign_options({
    modifiable = false,
    buflisted = false,
    bufhidden = 'wipe',
  })

  self.window = Window:open(buffer, {
    style = 'minimal',
    focusable = false,
    relative = 'editor',
    row = opts.row - HeaderElement:get_height(),
    col = opts.col,
    width = opts.width,
    height = 1,
    zindex = 100,
  }):assign_options({
    cursorbind = false,
    scrollbind = false,
    winhl = 'Normal:GitHeader',
  })
  self.namespace = Namespace()

  return self
end

function HeaderElement:unmount()
  self.window:close()

  return self
end

return HeaderElement
