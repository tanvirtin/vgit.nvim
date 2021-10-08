local dimensions = require('vgit.ui.dimensions')
local assertion = require('vgit.core.assertion')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local Component = Object:extend()

function Component:new(options)
  options = options or {}
  return setmetatable(
    utils.object_assign({
      buffer = nil,
      window = nil,
      cache = {},
      -- Elements are mini components which decorate a component.
      elements = {},
      -- The properties that can be used to align components with each other.
      window_props = {},
      config = {
        filetype = '',
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
          wrap = false,
          number = false,
          winhl = 'Normal:VGitBackgroundPrimary',
          cursorline = false,
          cursorbind = false,
          scrollbind = false,
          signcolumn = 'auto',
        },
        window_props = {
          style = 'minimal',
          relative = 'editor',
          height = 20,
          width = dimensions.global_width(),
          row = 0,
          col = 0,
          focusable = true,
          focus = true,
          zindex = 60,
        },
        locked = false,
      },
    }, options),
    Component
  )
end

function Component:set_width(width)
  self.window:set_width(width)
  return self
end

function Component:set_height(height)
  self.window:set_height(height)
  return self
end

function Component:set_window_props(window_props)
  self.window:set_window_props(window_props)
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

function Component:set_keymap(mode, key, action)
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
  self.config.filetype = filetype
  return self
end

function Component:get_filetype()
  return self.config.filetype
end

function Component:add_syntax_highlights()
  local buffer = self.buffer
  local config = self.config
  local filetype = config.filetype
  if not filetype or filetype == '' then
    return self
  end
  local has_ts = false
  local ts_highlight = nil
  local ts_parsers = nil
  if not has_ts then
    has_ts, _ = pcall(require, 'nvim-treesitter')
    if has_ts then
      _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
      _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
    end
  end
  if has_ts and filetype and filetype ~= '' then
    local lang = ts_parsers.ft_to_lang(filetype)
    if ts_parsers.has_parser(lang) then
      pcall(ts_highlight.attach, buffer.bufnr, lang)
    else
      buffer:set_option('syntax', filetype)
    end
  end
  return self
end

function Component:clear_syntax_highlights()
  local has_ts = false
  local buffer = self.buffer
  if not has_ts then
    has_ts, _ = pcall(require, 'nvim-treesitter')
  end
  if has_ts then
    local active_buf = vim.treesitter.highlighter.active[buffer.bufnr]
    if active_buf then
      active_buf:destroy()
    else
      buffer:set_option('syntax', '')
    end
  end
  return self
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
