local Component = require('vgit.ui.Component')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local LineNumberElement = Component:extend()

function LineNumberElement:new(...)
  return setmetatable(Component:new(...), LineNumberElement)
end

function LineNumberElement:get_width()
  return 6
end

function LineNumberElement:set_lines(lines)
  local actual_lines = {}
  local height = self.window:get_height()
  for _ = 1, #lines do
    actual_lines[#actual_lines + 1] = ''
  end
  for _ = 1, height - #lines do
    actual_lines[#actual_lines + 1] = ''
  end
  self.buffer:set_lines(actual_lines)
  return self
end

function LineNumberElement:mount(options)
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
      height = options.height,
      width = LineNumberElement:get_width(),
      zindex = 50,
    })
    :assign_options({
      cursorbind = true,
      scrollbind = true,
      winhl = 'Normal:GitBackgroundPrimary',
    })
  return self
end

function LineNumberElement:unmount()
  self.window:close()
  return self
end

return LineNumberElement
