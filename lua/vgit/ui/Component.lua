local loop = require('vgit.core.loop')
local assertion = require('vgit.core.assertion')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Component = Object:extend()

function Component:new(props)
  return setmetatable(
    utils.object.assign({
      buffer = nil,
      window = nil,
      notification = nil,
      namespace = nil,
      component_plot = nil,
      elements = {},
      -- Stores keypress callbacks
      keys = {},
      state = {},
      -- The properties that can be used to align components with each other.
      config = {
        border = {
          hl = 'GitBorder',
          chars = { '', '', '', '', '', '', '', '' },
        },
        buf_options = {
          modifiable = false,
          buflisted = false,
          bufhidden = 'wipe',
        },
        win_options = {
          winhl = 'Normal:GitBackgroundPrimary',
          signcolumn = 'auto',
          wrap = false,
          number = false,
          cursorline = false,
          cursorbind = false,
          scrollbind = false,
        },
        win_plot = {
          style = 'minimal',
          relative = 'editor',
          height = 20,
          width = '100vw',
          row = 0,
          col = 0,
          focusable = true,
          focus = true,
          zindex = 60,
        },
        locked = false,
      },
    }, props),
    Component
  )
end

function Component:attach_to_renderer(on_render)
  self.buffer:attach_to_renderer(on_render)
  return self
end

function Component:detach_from_renderer()
  self.buffer:detach_from_renderer()
  return self
end

function Component:set_width(width)
  self.window:set_width(width)
  return self
end

function Component:set_height(height)
  self.window:set_height(height)
  return self
end

function Component:set_win_plot(win_plot)
  self.window:set_win_plot(win_plot)
  return self
end

function Component:is_focused()
  return self.window:is_focused()
end

function Component:make_border(config)
  if config.hl then
    local new_border = {}
    for _, char in pairs(config.chars) do
      if type(char) == 'table' then
        char[2] = config.hl
        new_border[#new_border + 1] = char
      else
        new_border[#new_border + 1] = { char, config.hl }
      end
    end
    return new_border
  end
  return config.chars
end

function Component:mount()
  assertion.assert('Not yet implemented', debug.traceback())
end

function Component:unmount()
  assertion.assert('Not yet implemented', debug.traceback())
end

function Component:clear_namespace()
  self.buffer:clear_namespace()
  return self
end

function Component:add_highlight(hl, row, col_top, col_end)
  self.buffer:add_highlight(hl, row, col_top, col_end)
  return self
end

function Component:sign_place(lnum, sign_name)
  self.buffer:sign_place(lnum, sign_name)
  return self
end

function Component:sign_unplace()
  self.buffer:sign_unplace()
  return self
end

function Component:transpose_virtual_text(text, hl, row, col, pos)
  self.buffer:transpose_virtual_text(text, hl, row, col, pos)
  return self
end

function Component:transpose_virtual_line(texts, col, pos)
  self.buffer:transpose_virtual_line(texts, col, pos)
  return self
end

function Component:trigger_keypress(key, ...)
  local callback = self.keys[key]
  loop.await_fast_event()
  if type(callback) == 'function' and self:is_focused() then
    callback(...)
  end
  return self
end

function Component:set_keymap(mode, key, action, callback)
  -- Storing the callback within this scope.
  if callback then
    self.keys[key] = callback
  end
  self.buffer:set_keymap(mode, key, action)
  return self
end

function Component:set_cursor(cursor)
  if not self.locked then
    self.window:set_cursor(cursor)
  end
  return self
end

function Component:set_lnum(lnum)
  if not self.locked then
    self.window:set_lnum(lnum)
  end
  return self
end

function Component:reset_cursor()
  return self.window:set_cursor({ 1, 1 })
end

function Component:get_lnum()
  return self.window:get_lnum()
end

function Component:get_line_count()
  return self.buffer:get_line_count()
end

function Component:set_filetype(filetype)
  self.buffer:set_option('filetype', filetype)
  self.buffer:set_option('ft', filetype)
  self.buffer:set_option('syntax', filetype)
  return self
end

function Component:get_filetype()
  return self.buffer:get_option('filetype')
end

function Component:set_lines(lines, force)
  if self.locked and not force then
    return self
  end
  self.buffer:set_lines(lines)
  return self
end

function Component:call(callback)
  self.window:call(callback)
  return self
end

function Component:lock()
  self.locked = true
  return self
end

function Component:unlock()
  self.locked = false
  return self
end

function Component:focus()
  self.window:focus()
  return self
end

return Component
