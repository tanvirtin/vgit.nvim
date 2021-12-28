local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')

local HorizontalBorderElement = Object:extend()

function HorizontalBorderElement:new()
  return setmetatable({
    buffer = nil,
    window = nil,
  }, HorizontalBorderElement)
end

function HorizontalBorderElement:mount(options)
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
      winhl = 'Normal:GitBorder',
    })
  self:set_lines({ string.rep('─', options.width) })
  return self
end

function HorizontalBorderElement:get_height()
  return 1
end

function HorizontalBorderElement:unmount()
  self.window:close()
  return self
end

function HorizontalBorderElement:set_lines(lines)
  self.buffer:set_lines(lines)
  return self
end

return HorizontalBorderElement
