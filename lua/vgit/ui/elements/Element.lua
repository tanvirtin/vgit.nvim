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
    _buffer = nil,
    _window = nil,
    _mounted = false,
    _lines = nil,
    _on_render = function() end,
    _is_attached_to_renderer = false,
    _plot = props.plot or {
      win_plot = utils.object.assign(props.win_plot or {}),
    },
    _config = {
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
  if self._mounted then return self end

  self._buffer = Buffer():create()
  self._buffer:assign_options(self._config.buf_options)

  local win_plot = self._plot.win_plot or {}
  local window_mode = self._config.window_mode or 'popup'

  if win_plot.width then win_plot.width = LayoutContext.convert_dimension(win_plot.width) end
  if win_plot.height then win_plot.height = LayoutContext.convert_dimension(win_plot.height) end

  if window_mode == 'screen' then
    win_plot = vim.tbl_extend('force', win_plot or {}, {
      win_options = self._config.win_options,
    })
  end

  win_plot.mode = window_mode
  self._window = Window:open(self._buffer, win_plot)

  self:apply_window_options_explicitly()

  self._mounted = true

  if self._lines then
    self:set_lines(self._lines)
    self._lines = nil
  end

  return self
end

function Element:unmount()
  if not self._mounted then return self end

  self:detach_from_renderer()

  if self._window and self._window:is_valid() then self._window:close() end

  if self._buffer and self._buffer:is_valid() then self._buffer:delete({ force = true }) end

  self._mounted = false

  return self
end

function Element:is_valid()
  return self._mounted and self._buffer and self._buffer:is_valid() and self._window and self._window:is_valid()
end

function Element:set_lines(lines)
  if not self:is_valid() then return self end
  self._buffer:set_lines(lines)
  return self
end

function Element:get_lines()
  if not self:is_valid() then return {} end
  return self._buffer:get_lines()
end

function Element:clear_lines()
  return self:set_lines({})
end

function Element:get_line_count()
  if not self:is_valid() then return 0 end
  return self._buffer:get_line_count()
end

function Element:set_cursor(cursor)
  if not self:is_valid() then return self end
  self._window:set_cursor(cursor)
  return self
end

function Element:get_cursor()
  if not self:is_valid() then return { 1, 1 } end
  return self._window:get_cursor()
end

function Element:set_lnum(lnum)
  if not self:is_valid() then return self end
  self._window:set_lnum(lnum)
  return self
end

function Element:get_lnum()
  if not self:is_valid() then return 1 end
  return self._window:get_lnum()
end

function Element:position_cursor(placement)
  if not self:is_valid() then return self end
  self._window:position_cursor(placement)
  return self
end

function Element:reset_cursor()
  return self:set_cursor({ 1, 1 })
end

function Element:set_width(width)
  if not self:is_valid() then return self end
  self._window:set_width(width)
  return self
end

function Element:set_height(height)
  if not self:is_valid() then return self end
  self._window:set_height(height)
  return self
end

function Element:get_width()
  if not self:is_valid() then return 0 end
  return self._window:get_width()
end

function Element:get_height()
  if not self:is_valid() then return 0 end
  return self._window:get_height()
end

function Element:focus()
  if not self:is_valid() then return self end
  self._window:focus()
  return self
end

function Element:is_focused()
  if not self:is_valid() then return false end
  return self._window:is_focused()
end

function Element:set_filetype(filetype)
  if not self:is_valid() then return self end
  self._buffer:set_option('filetype', filetype)
  self._buffer:set_option('ft', filetype)
  self._buffer:set_option('syntax', filetype)
  return self
end

function Element:get_filetype()
  if not self:is_valid() then return '' end
  return self._buffer:get_option('filetype')
end

function Element:place_extmark_text(opts)
  if not self:is_valid() then return nil end
  return self._buffer:place_extmark_text(opts)
end

function Element:place_extmark_lnum(opts)
  if not self:is_valid() then return nil end
  return self._buffer:place_extmark_lnum(opts)
end

function Element:place_extmark_sign(sign)
  if not self:is_valid() then return nil end
  return self._buffer:place_extmark_sign(sign)
end

function Element:place_extmark_highlight(opts)
  if not self:is_valid() then return nil end
  return self._buffer:place_extmark_highlight(opts)
end

function Element:clear_extmarks()
  if not self:is_valid() then return self end
  self._buffer:clear_extmarks()
  return self
end

function Element:clear_extmark_lnums()
  if not self:is_valid() then return self end
  self._buffer:clear_extmark_lnums()
  return self
end

function Element:clear_extmark_texts()
  if not self:is_valid() then return self end
  self._buffer:clear_extmark_texts()
  return self
end

function Element:clear_extmark_signs()
  if not self:is_valid() then return self end
  self._buffer:clear_extmark_signs()
  return self
end

function Element:clear_extmark_highlights(from, to)
  if not self:is_valid() then return self end
  self._buffer:clear_extmark_highlights(from, to)
  return self
end

function Element:set_keymap(opts_or_mode, callback_or_key, handler, desc)
  if not self:is_valid() then return self end

  if type(opts_or_mode) == 'table' then
    self._buffer:set_keymap(opts_or_mode, event.async(callback_or_key))
  else
    local opts = {
      mode = opts_or_mode,
      key = callback_or_key,
      desc = desc or '',
    }
    self._buffer:set_keymap(opts, event.async(handler))
  end

  return self
end

function Element:get_bufnr()
  return self._buffer and self._buffer.bufnr or nil
end

function Element:get_win_id()
  return self._window and self._window.win_id or nil
end

function Element:on(event_name, callback)
  if not self:is_valid() then return self end
  self._buffer:on(event_name, callback)
  return self
end

function Element:call(callback)
  if not self:is_valid() then return self end
  self._window:call(callback)
  return self
end

function Element:set_option(key, value)
  if not self:is_valid() then return self end
  self._window:set_option(key, value)
  return self
end

function Element:enable_cursorline()
  return self:set_option('cursorline', true)
end

function Element:disable_cursorline()
  return self:set_option('cursorline', false)
end

function Element:attach_to_renderer(on_render)
  self._on_render = on_render or function() end

  if not self._is_attached_to_renderer and self._buffer then
    self._buffer._on_render = function(top, bot)
      self._on_render(top, bot)
    end
    renderer.register_module()
    renderer.attach(self._buffer)
    self._is_attached_to_renderer = true
  end

  return self
end

function Element:detach_from_renderer()
  if self._buffer then renderer.detach(self._buffer) end
  self._is_attached_to_renderer = false
  return self
end

function Element:render(top, bot)
  self._on_render(top, bot)
  return self
end

function Element:apply_window_options_explicitly()
  if not self._window or not self._window:is_valid() then return self end

  local options = self._config.win_options or {}

  for key, value in pairs(options) do
    pcall(vim.api.nvim_set_option_value, key, value, { win = self._window.win_id })
  end

  return self
end

function Element:reapply_window_options()
  if self._mounted and self._window and self._window:is_valid() then self:apply_window_options_explicitly() end
  return self
end

function Element:update_window_options(new_options)
  if not new_options then return self end

  self._config.win_options = vim.tbl_deep_extend('force', self._config.win_options, new_options)

  if self._mounted then self:apply_window_options_explicitly() end

  return self
end

return Element
