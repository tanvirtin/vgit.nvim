local lazy = require('vgit.core.lazy')

local utils = lazy('vgit.core.utils')
local Element = lazy('vgit.ui.elements.Element')
local Component = lazy('vgit.ui.Component')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')

local ElementComponent = Component:extend()

local DEFAULT_BUF_OPTIONS = {
  modifiable = false,
  buflisted = false,
  bufhidden = 'wipe',
}

function ElementComponent:constructor(props)
  local instance = Component.constructor(self, props)

  instance._element = nil

  return instance
end

function ElementComponent:get_buf_options()
  return {}
end

function ElementComponent:get_win_options()
  return {}
end

function ElementComponent:get_win_plot()
  return nil
end

function ElementComponent:get_layout_opts()
  return { flex = 1 }
end

function ElementComponent:_create_element()
  local props = self.props
  local buf_options = utils.object.extend(DEFAULT_BUF_OPTIONS, self:get_buf_options() or {})

  if props.buf_options then buf_options = utils.object.extend(buf_options, props.buf_options) end
  if props.filetype then buf_options.filetype = props.filetype end

  local config = { buf_options = buf_options }
  local win_options = self:get_win_options()
  local win_plot = self:get_win_plot()

  if win_options or props.win_options then
    config.win_options = utils.object.extend(win_options or {}, props.win_options or {})
  end

  if win_plot then config.win_plot = utils.object.clone(win_plot) end
  if props.win_plot then config.win_plot = utils.object.extend(config.win_plot or {}, props.win_plot) end
  if props.plot then config.plot = props.plot end

  return Element(config)
end

function ElementComponent:mount()
  if self._mounted then return end
  if not self._element then self._element = self:_create_element() end

  self._mounted = true
end

function ElementComponent:_release_element()
  if not self._element then return end

  self._element:unmount()
  self._element = nil
end

function ElementComponent:unmount()
  if not self._mounted then return end

  self:on_unmount()
  self:_release_element()
  self._mounted = false
end

function ElementComponent:get_layout_spec()
  return LayoutSpec.view(self._element, self:get_layout_opts())
end

function ElementComponent:with_element(fn)
  if self._element and self._element:is_valid() then return fn(self._element) end
end

function ElementComponent:set_lines(lines, top, bot)
  self:with_element(function(el)
    el:set_lines(lines, top, bot)
  end)
  return self
end

function ElementComponent:clear_lines()
  self:with_element(function(el)
    el:clear_lines()
  end)
  return self
end

function ElementComponent:set_cursor(cursor)
  self:with_element(function(el)
    el:set_cursor(cursor)
  end)
  return self
end

function ElementComponent:set_lnum(lnum)
  self:with_element(function(el)
    el:set_lnum(lnum)
  end)
  return self
end

function ElementComponent:scroll_to(pos, offset)
  self:with_element(function(el)
    el:scroll_to(pos, offset)
  end)
  return self
end

function ElementComponent:reset_cursor()
  self:with_element(function(el)
    el:reset_cursor()
  end)
  return self
end

function ElementComponent:set_width(width)
  self:with_element(function(el)
    el:set_width(width)
  end)
  return self
end

function ElementComponent:set_height(height)
  self:with_element(function(el)
    el:set_height(height)
  end)
  return self
end

function ElementComponent:focus()
  self:with_element(function(el)
    el:focus()
  end)
  return self
end

function ElementComponent:start_insert()
  self:with_element(function(el)
    el:start_insert()
  end)
  return self
end

function ElementComponent:stop_insert()
  self:with_element(function(el)
    el:stop_insert()
  end)
  return self
end

function ElementComponent:set_filetype(filetype)
  self:with_element(function(el)
    el:set_filetype(filetype)
  end)
  return self
end

function ElementComponent:clear_extmarks()
  self:with_element(function(el)
    el:clear_extmarks()
  end)
  return self
end

function ElementComponent:clear_extmark_lnums()
  self:with_element(function(el)
    el:clear_extmark_lnums()
  end)
  return self
end

function ElementComponent:clear_extmark_texts()
  self:with_element(function(el)
    el:clear_extmark_texts()
  end)
  return self
end

function ElementComponent:clear_extmark_signs()
  self:with_element(function(el)
    el:clear_extmark_signs()
  end)
  return self
end

function ElementComponent:clear_extmark_highlights(...)
  local args = { ... }

  self:with_element(function(el)
    el:clear_extmark_highlights(unpack(args))
  end)
  return self
end

function ElementComponent:set_keymap(opts_or_mode, callback_or_key, handler, desc)
  self:with_element(function(el)
    el:set_keymap(opts_or_mode, callback_or_key, handler, desc)
  end)
  return self
end

function ElementComponent:on(event_name, callback)
  self:with_element(function(el)
    el:on(event_name, callback)
  end)
  return self
end

function ElementComponent:on_click(clicks, click_opts)
  return self:with_element(function(el)
    return el:on_click(clicks, click_opts)
  end) or function() end
end

function ElementComponent:attach_to_changes(callback)
  self:with_element(function(el)
    el:attach_to_changes(callback)
  end)
  return self
end

function ElementComponent:call(callback)
  self:with_element(function(el)
    el:call(callback)
  end)
  return self
end

function ElementComponent:set_win_option(key, value)
  self:with_element(function(el)
    el:set_win_option(key, value)
  end)
  return self
end

function ElementComponent:enable_cursorline()
  self:with_element(function(el)
    el:enable_cursorline()
  end)
  return self
end

function ElementComponent:disable_cursorline()
  self:with_element(function(el)
    el:disable_cursorline()
  end)
  return self
end

function ElementComponent:attach_to_renderer(callback)
  self:with_element(function(el)
    el:attach_to_renderer(callback)
  end)
  return self
end

function ElementComponent:detach_from_renderer()
  self:with_element(function(el)
    el:detach_from_renderer()
  end)
  return self
end

function ElementComponent:get_lines()
  return self:with_element(function(el)
    return el:get_lines()
  end)
end

function ElementComponent:get_line_count()
  return self:with_element(function(el)
    return el:get_line_count()
  end)
end

function ElementComponent:get_cursor()
  return self:with_element(function(el)
    return el:get_cursor()
  end)
end

function ElementComponent:get_lnum()
  return self:with_element(function(el)
    return el:get_lnum()
  end)
end

function ElementComponent:get_width()
  return self:with_element(function(el)
    return el:get_width()
  end)
end

function ElementComponent:get_height()
  return self:with_element(function(el)
    return el:get_height()
  end)
end

function ElementComponent:get_filetype()
  return self:with_element(function(el)
    return el:get_filetype()
  end)
end

function ElementComponent:is_focused()
  return self:with_element(function(el)
    return el:is_focused()
  end) or false
end

function ElementComponent:is_valid()
  return self:with_element(function()
    return true
  end) or false
end

function ElementComponent:place_extmark_text(extmark_opts)
  return self:with_element(function(el)
    return el:place_extmark_text(extmark_opts)
  end)
end

function ElementComponent:place_extmark_lnum(extmark_opts)
  return self:with_element(function(el)
    return el:place_extmark_lnum(extmark_opts)
  end)
end

function ElementComponent:place_extmark_sign(extmark_opts)
  return self:with_element(function(el)
    return el:place_extmark_sign(extmark_opts)
  end)
end

function ElementComponent:place_extmark_highlight(extmark_opts)
  return self:with_element(function(el)
    return el:place_extmark_highlight(extmark_opts)
  end)
end

return ElementComponent
