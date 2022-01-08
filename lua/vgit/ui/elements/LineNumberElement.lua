local dimensions = require('vgit.ui.dimensions')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local Object = require('vgit.core.Object')

local LineNumberElement = Object:extend()

function LineNumberElement:new()
  return setmetatable({
    buffer = nil,
    window = nil,
    runtime_cache = {
      lines = {},
    },
  }, LineNumberElement)
end

function LineNumberElement:attach_to_ui(on_render)
  self.buffer:attach_to_ui(on_render)
  return self
end

function LineNumberElement:set_lnum(lnum)
  self.window:set_lnum(lnum)
  return self
end

function LineNumberElement:set_cursor(cursor)
  self.window:set_cursor(cursor)
  return self
end

function LineNumberElement:reset_cursor()
  self.window:set_cursor({ 1, 1 })
  return self
end

function LineNumberElement:call(callback)
  self.window:call(callback)
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
      winhl = 'Normal:VGitBackgroundPrimary',
    })
  return self
end

function LineNumberElement:get_width()
  return 6
end

function LineNumberElement:make_lines(lines)
  local global_height = dimensions.global_height()
  local actual_lines = {}
  for _ = 1, #lines do
    actual_lines[#actual_lines + 1] = ''
  end
  for _ = #lines, global_height do
    actual_lines[#actual_lines + 1] = ''
  end
  self.buffer:set_lines(actual_lines)
  self.runtime_cache.lines = lines
  return self
end

function LineNumberElement:sign_place(lnum, defined_sign)
  self.buffer:sign_place(lnum, defined_sign)
  return self
end

function LineNumberElement:transpose_virtual_line(texts, col, pos)
  self.buffer:transpose_virtual_line(texts, col, pos)
  return self
end

function LineNumberElement:clear_namespace()
  self.buffer:clear_namespace()
  return self
end

function LineNumberElement:unmount()
  self.window:close()
  return self
end

return LineNumberElement
