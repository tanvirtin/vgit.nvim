local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local Component = require('vgit.ui.Component')

local HeaderElement = Component:extend()

function HeaderElement:constructor(...)
  return Component.constructor(self, ...)
end

function HeaderElement:get_height()
  return 1
end

function HeaderElement:trigger_notification(text)
  self:place_extmark_text({
    text = text,
    hl = 'GitComment',
    row = 0,
    col = 0,
    pos = 'eol',
  })

  return self
end

function HeaderElement:clear_notification()
  self:clear_extmark_texts()
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
    zindex = 5,
  }):assign_options({
    cursorbind = false,
    scrollbind = false,
    winhl = 'Normal:GitHeader',
  })

  return self
end

function HeaderElement:unmount()
  self.window:close()
  return self
end

return HeaderElement
