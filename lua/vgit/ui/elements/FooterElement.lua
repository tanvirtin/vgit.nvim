local Component = require('vgit.ui.Component')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local FooterElement = Component:extend()

function FooterElement:new(...)
  return setmetatable(Component:new(...), FooterElement)
end

function FooterElement:get_height()
  return 1
end

function FooterElement:mount(options)
  self.buffer = Buffer:new():create()
  local buffer = self.buffer
  buffer:assign_options({
    modifiable = false,
    bufhidden = 'wipe',
    buflisted = false,
  })
  self.window = Window
    :open(buffer, {
      style = 'minimal',
      focusable = false,
      relative = 'editor',
      row = options.row,
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
  local border_char = ' '
  self:set_lines({ string.rep(border_char, options.width) })
  return self
end

function FooterElement:unmount()
  self.window:close()
  return self
end

return FooterElement
