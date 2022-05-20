local Component = require('vgit.ui.Component')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local LineNumberElement = Component:extend()

function LineNumberElement:constructor(...)
  return Component.constructor(self, ...)
end

function LineNumberElement:get_width()
  return 6
end

function LineNumberElement:make_lines(lines)
  local num_lines = #lines

  local actual_lines = {}

  for _ = 1, num_lines do
    actual_lines[#actual_lines + 1] = ''
  end

  self.buffer:set_lines(actual_lines)

  return self
end

function LineNumberElement:mount(opts)
  opts = opts or {}
  local buffer = Buffer():create()

  self.buffer = buffer

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
      row = opts.row,
      col = opts.col,
      height = opts.height,
      width = LineNumberElement:get_width(),
      zindex = 50,
    })
    :assign_options({
      cursorbind = true,
      scrollbind = true,
      winhl = 'Normal:GitBackground',
    })

  return self
end

function LineNumberElement:unmount()
  self.window:close()

  return self
end

return LineNumberElement
