local Component = require('vgit.ui.Component')
local Namespace = require('vgit.core.Namespace')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local HeaderElement = Component:extend()

function HeaderElement:new(...)
  return setmetatable(Component:new(...), HeaderElement)
end

function HeaderElement:get_height()
  return 1
end

function HeaderElement:trigger_notification(text)
  self.namespace:transpose_virtual_text(
    self.buffer,
    text,
    'GitComment',
    0,
    0,
    'eol'
  )
  return self
end

function HeaderElement:clear_notification()
  if self.buffer:is_valid() then
    self.namespace:clear(self.buffer)
  end
  return self
end

function HeaderElement:mount(options)
  self.buffer = Buffer:new():create()
  local buffer = self.buffer
  buffer:assign_options({
    modifiable = false,
    buflisted = false,
    bufhidden = 'wipe',
  })
  self.window = Window
    :open(buffer, {
      style = 'minimal',
      focusable = false,
      relative = 'editor',
      row = options.row - HeaderElement:get_height(),
      col = options.col,
      width = options.width,
      height = 1,
      zindex = 100,
    })
    :assign_options({
      cursorbind = false,
      scrollbind = false,
      winhl = 'Normal:GitBackgroundSecondary',
    })
  self.namespace = Namespace:new()
  return self
end

function HeaderElement:unmount()
  self.window:close()
  return self
end

return HeaderElement
