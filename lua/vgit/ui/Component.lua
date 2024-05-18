local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')
local ComponentPlot = require('vgit.ui.ComponentPlot')

local Component = Object:extend()

-- create plot in runtime.
function Component:constructor(props)
  props = utils.object.assign({
    buffer = nil,
    window = nil,
    notification = nil,
    namespace = nil,
    plot = nil,
    mounted = false,
    elements = {},
    state = {},
    -- The properties that can be used to align components with each other.
    config = {
      elements = {},
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
        winhl = 'Normal:GitBackground',
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
        zindex = 2,
      },
      locked = false,
    },
  }, props)

  props.plot = ComponentPlot(props.config.win_plot, props.config.elements):build()

  return props
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

function Component:on(event_name, callback)
  self.buffer:on(event_name, callback)

  return self
end

function Component:is_focused() return self.window:is_focused() end

function Component:is_valid() return self.buffer:is_valid() and self.window:is_valid() end

function Component:render_border(config)
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

function Component:mount() assertion.assert('Not yet implemented') end

function Component:unmount() assertion.assert('Not yet implemented') end

function Component:clear_namespace()
  self.buffer:clear_namespace()

  return self
end

function Component:add_highlight(hl, row, col_top, col_end)
  self.buffer:add_highlight(hl, row, col_top, col_end)

  return self
end

function Component:add_pattern_highlight(pattern, hl)
  self.buffer:add_pattern_highlight(pattern, hl)

  return self
end

function Component:clear_highlight(row_start, row_end)
  self.buffer:clear_highlight(row_start, row_end)

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

function Component:transpose_virtual_line_number(text, row)
  self.buffer:transpose_virtual_line_number(text, row)

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

function Component:set_keymap(mode, key, callback)
  self.buffer:set_keymap(mode, key, callback)

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

function Component:position_cursor(placement)
  self.window:position_cursor(placement)

  return self
end

function Component:enable_cursorline()
  self.window:set_option('cursorline', true)

  return self
end

function Component:disable_cursorline()
  self.window:set_option('cursorline', false)

  return self
end

function Component:clear_lines() return self.buffer:set_lines({}) end

function Component:reset_cursor() return self.window:set_cursor({ 1, 1 }) end

function Component:get_plot() return self.plot end

function Component:get_lnum() return self.window:get_lnum() end

function Component:get_line_count() return self.buffer:get_line_count() end

function Component:set_filetype(filetype)
  self.buffer:set_option('filetype', filetype)
  self.buffer:set_option('ft', filetype)
  self.buffer:set_option('syntax', filetype)

  return self
end

function Component:get_filetype() return self.buffer:get_option('filetype') end

function Component:get_lines() return self.buffer:get_lines() end

function Component:set_lines(lines, force)
  if self.locked and not force or not self:is_valid() then
    return self
  end

  self.buffer:set_lines(lines)

  return self
end

function Component:is_own_window(window) return self.window:is_same(window) end

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
