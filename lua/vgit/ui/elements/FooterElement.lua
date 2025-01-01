local Component = require('vgit.ui.Component')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local FooterElement = Component:extend()

function FooterElement:constructor(...)
  return Component.constructor(self, ...)
end

function FooterElement:get_height()
  return 1
end

function FooterElement:mount(opts)
  local buffer = Buffer():create()
  self.buffer = buffer

  buffer:assign_options({
    modifiable = false,
    bufhidden = 'wipe',
    buflisted = false,
  })
  self.window = Window:open(buffer, {
    style = 'minimal',
    focusable = false,
    relative = 'editor',
    row = opts.row,
    col = opts.col,
    width = opts.width,
    height = 1,
    zindex = 5,
  }):assign_options({
    cursorbind = false,
    scrollbind = false,
    winhl = 'Normal:GitFooter',
  })
  local border_char = ' '

  self:set_lines({ string.rep(border_char, opts.width) })

  return self
end

function FooterElement:unmount()
  self.window:close()
  return self
end

return FooterElement
