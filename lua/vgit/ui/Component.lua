local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local assertion = require('vgit.core.assertion')
local ComponentPlot = require('vgit.ui.ComponentPlot')

local Component = Object:extend()

function Component:constructor(props)
  props = utils.object.assign({
    buffer = nil,
    window = nil,
    notification = nil,
    plot = nil,
    mounted = false,
    elements = {},
    state = {},
    config = {
      elements = {},
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

function Component:is_focused()
  return self.window:is_focused()
end

function Component:is_valid()
  return self.buffer:is_valid() and self.window:is_valid()
end

function Component:mount()
  assertion.assert('Not yet implemented')
end

function Component:unmount()
  assertion.assert('Not yet implemented')
end

function Component:clear_extmark_lnums()
  return self.buffer:clear_extmark_lnums()
end

function Component:clear_extmark_texts()
  return self.buffer:clear_extmark_texts()
end

function Component:clear_extmark_signs()
  return self.buffer:clear_extmark_signs()
end

function Component:clear_extmark_highlights()
  return self.buffer:clear_extmark_highlights()
end

function Component:clear_extmarks()
  return self.buffer:clear_extmarks()
end

function Component:place_extmark_text(opts)
  return self.buffer:place_extmark_text(opts)
end

function Component:place_extmark_lnum(opts)
  return self.buffer:place_extmark_lnum(opts)
end

function Component:place_extmark_sign(sign)
  return self.buffer:place_extmark_sign(sign)
end

function Component:place_extmark_highlight(opts)
  return self.buffer:place_extmark_highlight(opts)
end

function Component:set_keymap(opts, callback)
  self.buffer:set_keymap(opts, callback)
  return self
end

function Component:set_cursor(cursor)
  if not self.locked then self.window:set_cursor(cursor) end
  return self
end

function Component:set_lnum(lnum)
  if not self.locked then self.window:set_lnum(lnum) end
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

function Component:clear_lines()
  self.buffer:set_lines({})
  return self
end

function Component:reset_cursor()
  self.window:set_cursor({ 1, 1 })
  return self
end

function Component:get_plot()
  return self.plot
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

function Component:get_lines()
  return self.buffer:get_lines()
end

function Component:set_lines(lines, force)
  if self.locked and not force or not self:is_valid() then return self end
  self.buffer:set_lines(lines)
  return self
end

function Component:is_own_window(window)
  return self.window:is_same(window)
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
