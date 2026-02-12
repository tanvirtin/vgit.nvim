local lazy = require('vgit.core.lazy')
local event = lazy('vgit.core.event')
local utils = lazy('vgit.core.utils')
local Object = lazy('vgit.core.Object')
local Buffer = lazy('vgit.core.Buffer')
local Window = lazy('vgit.core.Window')
local renderer = lazy('vgit.core.renderer')
local LayoutContext = lazy('vgit.ui.layout.LayoutContext')

local Element = Object:extend()

function Element:constructor(props)
  props = props or {}

  return {
    props = props,
    buffer = nil,
    window = nil,
    mounted = false,
    _lines = nil,
    on_render = function() end,
    is_attached_to_renderer = false,
    plot = props.plot or {
      win_plot = utils.object.assign(props.win_plot or {}),
    },
    config = {
      window_mode = nil,
      buf_options = props.buf_options or {
        modifiable = false,
        buflisted = false,
        bufhidden = 'wipe',
      },
      win_options = props.win_options or {
        winhl = 'Normal:GitBackground',
        signcolumn = 'auto',
        wrap = false,
        number = false,
        cursorline = false,
      },
    },
  }
end

function Element:mount()
  if self.mounted then return self end

  self.buffer = Buffer():create()
  self.buffer:assign_options(self.config.buf_options)

  local win_plot = self.plot.win_plot or {}
  local window_mode = self.config.window_mode or 'popup'

  if win_plot.width then win_plot.width = LayoutContext.convert_dimension(win_plot.width) end
  if win_plot.height then win_plot.height = LayoutContext.convert_dimension(win_plot.height) end

  if window_mode == 'screen' then
    win_plot = vim.tbl_extend('force', win_plot or {}, {
      win_options = self.config.win_options,
    })
  end

  win_plot.mode = window_mode
  self.window = Window:open(self.buffer, win_plot)

  self:apply_window_options_explicitly()

  self.mounted = true

  if self._lines then
    self:set_lines(self._lines)
    self._lines = nil
  end

  return self
end

function Element:unmount()
  if not self.mounted then return self end

  if self.window and self.window:is_valid() then self.window:close() end

  if self.buffer and self.buffer:is_valid() then self.buffer:delete({ force = true }) end

  self.mounted = false

  return self
end

function Element:is_valid()
  return self.mounted and self.buffer and self.buffer:is_valid() and self.window and self.window:is_valid()
end

function Element:set_lines(lines)
  if not self:is_valid() then return self end
  self.buffer:set_lines(lines)
  return self
end

function Element:get_lines()
  if not self:is_valid() then return {} end
  return self.buffer:get_lines()
end

function Element:clear_lines()
  return self:set_lines({})
end

function Element:get_line_count()
  if not self:is_valid() then return 0 end
  return self.buffer:get_line_count()
end

function Element:set_cursor(cursor)
  if not self:is_valid() then return self end
  self.window:set_cursor(cursor)
  return self
end

function Element:get_cursor()
  if not self:is_valid() then return { 1, 1 } end
  return self.window:get_cursor()
end

function Element:set_lnum(lnum)
  if not self:is_valid() then return self end
  self.window:set_lnum(lnum)
  return self
end

function Element:get_lnum()
  if not self:is_valid() then return 1 end
  return self.window:get_lnum()
end

function Element:position_cursor(placement)
  if not self:is_valid() then return self end
  self.window:position_cursor(placement)
  return self
end

function Element:reset_cursor()
  return self:set_cursor({ 1, 1 })
end

function Element:set_width(width)
  if not self:is_valid() then return self end
  self.window:set_width(width)
  return self
end

function Element:set_height(height)
  if not self:is_valid() then return self end
  self.window:set_height(height)
  return self
end

function Element:get_width()
  if not self:is_valid() then return 0 end
  return self.window:get_width()
end

function Element:get_height()
  if not self:is_valid() then return 0 end
  return self.window:get_height()
end

function Element:focus()
  if not self:is_valid() then return self end
  self.window:focus()
  return self
end

function Element:is_focused()
  if not self:is_valid() then return false end
  return self.window:is_focused()
end

function Element:set_filetype(filetype)
  if not self:is_valid() then return self end
  self.buffer:set_option('filetype', filetype)
  self.buffer:set_option('ft', filetype)
  self.buffer:set_option('syntax', filetype)
  return self
end

function Element:get_filetype()
  if not self:is_valid() then return '' end
  return self.buffer:get_option('filetype')
end

function Element:place_extmark_text(opts)
  if not self:is_valid() then return nil end
  return self.buffer:place_extmark_text(opts)
end

function Element:place_extmark_lnum(opts)
  if not self:is_valid() then return nil end
  return self.buffer:place_extmark_lnum(opts)
end

function Element:place_extmark_sign(sign)
  if not self:is_valid() then return nil end
  return self.buffer:place_extmark_sign(sign)
end

function Element:place_extmark_highlight(opts)
  if not self:is_valid() then return nil end
  return self.buffer:place_extmark_highlight(opts)
end

function Element:clear_extmarks()
  if not self:is_valid() then return self end
  self.buffer:clear_extmarks()
  return self
end

function Element:clear_extmark_lnums()
  if not self:is_valid() then return self end
  self.buffer:clear_extmark_lnums()
  return self
end

function Element:clear_extmark_texts()
  if not self:is_valid() then return self end
  self.buffer:clear_extmark_texts()
  return self
end

function Element:clear_extmark_signs()
  if not self:is_valid() then return self end
  self.buffer:clear_extmark_signs()
  return self
end

function Element:clear_extmark_highlights()
  if not self:is_valid() then return self end
  self.buffer:clear_extmark_highlights()
  return self
end

function Element:set_keymap(opts_or_mode, callback_or_key, handler, desc)
  if not self:is_valid() then return self end
  
  if type(opts_or_mode) == 'table' then
    self.buffer:set_keymap(opts_or_mode, event.async(callback_or_key))
  else
    local opts = {
      mode = opts_or_mode,
      key = callback_or_key,
      desc = desc or '',
    }
    self.buffer:set_keymap(opts, event.async(handler))
  end

  return self
end

function Element:get_bufnr()
  return self.buffer and self.buffer.bufnr or nil
end

function Element:get_win_id()
  return self.window and self.window.win_id or nil
end

function Element:on(event_name, callback)
  if not self:is_valid() then return self end
  self.buffer:on(event_name, callback)
  return self
end

function Element:call(callback)
  if not self:is_valid() then return self end
  self.window:call(callback)
  return self
end

function Element:set_option(key, value)
  if not self:is_valid() then return self end
  self.window:set_option(key, value)
  return self
end

function Element:enable_cursorline()
  return self:set_option('cursorline', true)
end

function Element:disable_cursorline()
  return self:set_option('cursorline', false)
end

function Element:attach_to_renderer(on_render)
  self.on_render = on_render or function() end

  if not self.is_attached_to_renderer and self.buffer then
    self.buffer.on_render = function(top, bot)
      self.on_render(top, bot)
    end
    renderer.register_module()
    renderer.attach(self.buffer)
    self.is_attached_to_renderer = true
  end

  return self
end

function Element:detach_from_renderer()
  if self.buffer then renderer.detach(self.buffer) end
  self.is_attached_to_renderer = false
  return self
end

function Element:render(top, bot)
  self.on_render(top, bot)
  return self
end

function Element:apply_window_options_explicitly()
  if not self.window or not self.window:is_valid() then return self end

  local options = self.config.win_options or {}

  for key, value in pairs(options) do
    pcall(vim.api.nvim_win_set_option, self.window.win_id, key, value)
  end

  return self
end

function Element:reapply_window_options()
  if self.mounted and self.window and self.window:is_valid() then self:apply_window_options_explicitly() end
  return self
end

function Element:update_window_options(new_options)
  if not new_options then return self end

  self.config.win_options = vim.tbl_deep_extend('force', self.config.win_options, new_options)

  if self.mounted then self:apply_window_options_explicitly() end

  return self
end

return Element
