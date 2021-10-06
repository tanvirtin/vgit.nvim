local Object = require('plenary.class')
local dimensions = require('vgit.dimensions')
local render_store = require('vgit.stores.render_store')
local navigation = require('vgit.navigation')
local virtual_text = require('vgit.virtual_text')
local sign = require('vgit.sign')
local autocmd = require('vgit.autocmd')
local assert = require('vgit.assertion').assert
local buffer = require('vgit.buffer')
local VirtualLineNrDecorator = require('vgit.decorators.VirtualLineNrDecorator')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local Interface = require('vgit.Interface')

local Component = Object:extend()

Component.state = Interface:new({
  loading = {
    frame_rate = 60,
    frames = {
      '∙∙∙',
      '●∙∙',
      '∙●∙',
      '∙∙●',
      '∙∙∙',
    },
  },
  error = '✖✖✖',
})

function Component:setup(config)
  Component.state:assign(config)
end

function Component:new(options)
  assert(
    options == nil or type(options) == 'table',
    'type error :: expected table or nil'
  )
  options = options or {}
  local height = self:get_min_height()
  local width = self:get_min_width()
  return setmetatable({
    anim_id = nil,
    timer_id = nil,
    state = {
      buf = nil,
      win_id = nil,
      ns_id = nil,
      virtual_line_nr = nil,
      loading = false,
      error = false,
      mounted = false,
      cache = {
        lines = {},
        cursor = nil,
      },
      paint_count = 0,
    },
    config = Interface
      :new({
        filetype = '',
        border = {
          enabled = false,
          hl = 'FloatBorder',
          chars = { '', '', '', '', '', '', '', '' },
        },
        buf_options = {
          ['modifiable'] = false,
          ['buflisted'] = false,
          ['bufhidden'] = 'wipe',
        },
        win_options = {
          ['wrap'] = false,
          ['number'] = false,
          ['winhl'] = 'Normal:',
          ['cursorline'] = false,
          ['cursorbind'] = false,
          ['scrollbind'] = false,
          ['signcolumn'] = 'auto',
        },
        window_props = {
          style = 'minimal',
          relative = 'editor',
          height = height,
          width = width,
          row = 1,
          col = 0,
          focusable = true,
          zindex = 50,
        },
        virtual_line_nr = {
          enabled = false,
          width = render_store.get('preview').virtual_line_nr_width,
        },
        static = false,
      })
      :assign(options),
  }, Component)
end

function Component:is_virtual_line_nr_enabled()
  return self.config:get('virtual_line_nr').enabled
end

function Component:has_virtual_line_nr()
  return self:get_virtual_line_nr() and self:is_virtual_line_nr_enabled()
end

function Component:is_border_enabled()
  return self.config:get('border').enabled
end

function Component:is_static()
  return self.config:get('static')
end

function Component:is_hover()
  return self.config:get('window_props').relative == 'cursor'
end

function Component:is_focused()
  return vim.api.nvim_get_current_win() == self:get_win_id()
end

function Component:has_lines()
  return self:get_paint_count() > 0
end

function Component:get_paint_count()
  return self.state.paint_count
end

function Component:get_win_ids()
  return { self:get_win_id(), self:get_virtual_line_nr_win_id() }
end

function Component:get_bufs()
  return { self:get_buf(), self:get_virtual_line_nr_buf() }
end

function Component:get_win_id()
  return self.state.win_id
end

function Component:get_buf()
  return self.state.buf
end

function Component:get_ns_id()
  return self.state.ns_id
end

function Component:get_virtual_line_nr_buf()
  return self:get_virtual_line_nr() and self:get_virtual_line_nr():get_buf()
    or nil
end

function Component:get_virtual_line_nr_win_id()
  return self:get_virtual_line_nr()
      and self:get_virtual_line_nr():get_win_id()
    or nil
end

function Component:get_buf_option(key)
  return buffer.get_option(self:get_win_id(), key)
end

function Component:get_win_option(key)
  return vim.api.nvim_win_get_option(self:get_win_id(), key)
end

function Component:get_lines()
  return buffer.get_lines(self:get_buf())
end

function Component:get_height()
  return vim.api.nvim_win_get_height(self:get_win_id())
end

function Component:get_width()
  return vim.api.nvim_win_get_width(self:get_win_id())
end

function Component:get_min_height()
  return 20
end

function Component:get_min_width()
  return 70
end

function Component:get_cached_lines()
  return self.state.cache.lines
end

function Component:get_cached_cursor()
  return self.state.cache.cursor
end

function Component:get_loading()
  return self.state.loading
end

function Component:get_error()
  return self.state.error
end

function Component:get_virtual_line_nr()
  return self.state.virtual_line_nr
end

function Component:is_mounted()
  return self.state.mounted
end

function Component:set_virtual_line_nr(virtual_line_nr)
  assert(type(virtual_line_nr) == 'table', 'type error :: expected table')
  self.state.virtual_line_nr = virtual_line_nr
  return self
end

function Component:set_ns_id(value)
  assert(type(value) == 'number', 'type error :: expected number')
  self.state.ns_id = value
  return self
end

function Component:set_buf(value)
  assert(type(value) == 'number', 'type error :: expected number')
  self.state.buf = value
  return self
end

function Component:set_win_id(value)
  assert(type(value) == 'number', 'type error :: expected number')
  self.state.win_id = value
  return self
end

function Component:set_cached_lines(value)
  assert(vim.tbl_islist(value), 'type error :: expected list table')
  self.state.cache.lines = value
  return self
end

function Component:set_cached_cursor(value)
  assert(vim.tbl_islist(value), 'type error :: expected list table')
  self.state.cache.cursor = value
  return self
end

function Component:set_height(value)
  assert(type(value) == 'number', 'type error :: expected number')
  vim.api.nvim_win_set_height(self:get_win_id(), value)
  return self
end

function Component:set_width(value)
  assert(type(value) == 'number', 'type error :: expected number')
  vim.api.nvim_win_set_width(self:get_win_id(), value)
  return self
end

function Component:add_syntax_highlights()
  local filetype = self.config:get('filetype')
  if not filetype or filetype == '' then
    return self
  end
  local buf = self:get_buf()
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
      pcall(ts_highlight.attach, buf, lang)
    else
      buffer.set_option(buf, 'syntax', filetype)
    end
  end
  return self
end

function Component:clear_syntax_highlights()
  local buf = self:get_buf()
  local has_ts = false
  if not has_ts then
    has_ts, _ = pcall(require, 'nvim-treesitter')
  end
  if has_ts then
    local active_buf = vim.treesitter.highlighter.active[buf]
    if active_buf then
      active_buf:destroy()
    else
      buffer.set_option(buf, 'syntax', '')
    end
  end
  return self
end

function Component:increment_paint_count()
  self.state.paint_count = self.state.paint_count + 1
  return self
end

function Component:set_filetype(filetype)
  assert(type(filetype) == 'string', 'type error :: expected string')
  self.config:set('filetype', filetype)
  local buf = self:get_buf()
  self:clear_syntax_highlights()
  self:add_syntax_highlights()
  buffer.set_option(buf, 'syntax', filetype)
  return self
end

function Component:set_cursor(row, col)
  assert(type(row) == 'number', 'type error :: expected number')
  assert(type(col) == 'number', 'type error :: expected number')
  navigation.set_cursor(self:get_win_id(), { row, col })
  if self:has_virtual_line_nr() then
    navigation.set_cursor(self:get_virtual_line_nr_win_id(), { row, col })
  end
  return self
end

function Component:set_buf_option(option, value)
  vim.api.nvim_buf_set_option(self:get_buf(), option, value)
  return self
end

function Component:set_win_option(option, value)
  vim.api.nvim_win_set_option(self:get_win_id(), option, value)
  return self
end

function Component:set_lines(lines, force)
  if self:is_static() and self:has_lines() and not force then
    return self
  end
  assert(type(lines) == 'table', 'type error :: expected table')
  self:increment_paint_count()
  self:clear_timers()
  buffer.set_lines(self:get_buf(), lines)
  return self
end

function Component:set_virtual_line_nr_lines(lines, hls)
  assert(type(lines) == 'table', 'type error :: expected table')
  assert(
    self:has_virtual_line_nr(),
    'cannot set virtual number lines -- virtual number is disabled'
  )
  assert(self:get_virtual_line_nr(), 'VirtualLineNrDecorator not created')
  local virtual_line_nr = self:get_virtual_line_nr()
  virtual_line_nr:unmount()
  self:set_virtual_line_nr(
    VirtualLineNrDecorator:new(
      self.config:get('virtual_line_nr'),
      self.config:get('window_props'),
      self:get_buf()
    )
  )
  virtual_line_nr = self:get_virtual_line_nr()
  virtual_line_nr:mount()
  virtual_line_nr:set_lines(lines)
  virtual_line_nr:set_hls(hls)
  return self
end

function Component:set_centered_animated_text(
  frame_rate,
  frames,
  force,
  callback
)
  assert(type(frame_rate) == 'number', 'type error :: expected number')
  assert(vim.tbl_islist(frames), 'type error :: expected list table')
  self:clear_timers()
  self:set_centered_text(frames[1], true, force)
  local frame_count = 1
  self.anim_id = vim.fn.timer_start(
    frame_rate,
    void(function()
      scheduler()
      if buffer.is_valid(self:get_buf()) then
        frame_count = frame_count + 1
        local selected_frame = frame_count % #frames
        selected_frame = selected_frame == 0 and 1 or selected_frame
        self:set_centered_text(
          string.format('%s', frames[selected_frame]),
          true
        )
        if callback then
          callback(frame_rate, frames, self.anim_id)
        end
      else
        self:clear_timers()
      end
    end),
    {
      ['repeat'] = -1,
    }
  )
  return self
end

function Component:set_loading(value, force)
  if self:is_static() and self:has_lines() and not force then
    return self
  end
  assert(type(value) == 'boolean', 'type error :: expected boolean')
  self:clear_timers()
  if value == self:get_loading() then
    return self
  end
  if value then
    self:set_cached_cursor(vim.api.nvim_win_get_cursor(self:get_win_id()))
    self.state.loading = value
    local animation_configuration = Component.state:get('loading')
    self:set_centered_animated_text(
      animation_configuration.frame_rate,
      animation_configuration.frames,
      force
    )
  else
    self:add_syntax_highlights()
    self.state.loading = value
    buffer.set_lines(self:get_buf(), self:get_cached_lines())
    self:set_win_option('cursorline', self.config:get('win_options').cursorline)
    navigation.set_cursor(self:get_win_id(), self:get_cached_cursor())
    self:set_cached_lines({})
    self.state.cursor = nil
  end
  return self
end

function Component:set_error(value, force)
  if self:is_static() and self:has_lines() and not force then
    return self
  end
  assert(type(value) == 'boolean', 'type error :: expected boolean')
  self:clear_timers()
  if value == self:get_error() then
    return self
  end
  if value then
    self.state.error = value
    self:set_centered_text(Component.state:get('error'))
  else
    self:add_syntax_highlights()
    self.state.error = value
    buffer.set_lines(self:get_buf(), self:get_cached_lines())
    self:set_win_option('cursorline', self.config:get('win_options').cursorline)
    self:set_cached_lines({})
  end
  return self
end

function Component:set_centered_text(text, in_animation, force)
  if self:is_static() and self:has_lines() and not force then
    return self
  end
  assert(type(text) == 'string', 'type error :: expected string')
  if not in_animation then
    self:clear_timers()
  end
  self:clear_syntax_highlights()
  local lines = {}
  local win_id = self:get_win_id()
  local height = vim.api.nvim_win_get_height(win_id)
  local width = vim.api.nvim_win_get_width(win_id)
  for _ = 1, height do
    lines[#lines + 1] = ''
  end
  lines[math.ceil(height / 2)] = string.rep(
    ' ',
    dimensions.calculate_text_center(text, width)
  ) .. text
  self:set_win_option('cursorline', false)
  self:set_cached_lines(buffer.get_lines(self:get_buf()))
  buffer.set_lines(self:get_buf(), lines)
  if self:has_virtual_line_nr() then
    buffer.set_lines(self:get_virtual_line_nr_buf(), {})
  end
  return self
end

function Component:set_mounted(value)
  assert(type(value) == 'boolean', 'type error :: expected boolean')
  self.state.mounted = value
  return self
end

function Component:on(cmd, handler, options)
  autocmd.buf.on(self:get_buf(), cmd, handler, options)
  return self
end

function Component:add_keymap(key, action)
  buffer.add_keymap(self:get_buf(), key, action)
  return self
end

function Component:remove_keymap(key)
  buffer.remove_keymap(self:get_buf(), key)
  return self
end

function Component:transpose_text(text, row, col)
  assert(vim.tbl_islist(text), 'type error :: expected list table')
  assert(#text == 2, 'invalid number of text entries')
  assert(type(row) == 'number', 'type error :: expected number')
  assert(type(col) == 'number', 'type error :: expected number')
  virtual_text.transpose_text(
    self:get_buf(),
    text[1],
    self:get_ns_id(),
    text[2],
    row,
    col
  )
end

function Component:transpose_line(texts, row)
  assert(vim.tbl_islist(texts), 'type error :: expected list table')
  assert(type(row) == 'number', 'type error :: expected number')
  virtual_text.transpose_line(self:get_buf(), texts, self:get_ns_id(), row)
end

function Component:call(fn)
  assert(type(fn) == 'function', 'type error :: expected function')
  vim.api.nvim_buf_call(self:get_buf(), fn)
  return self
end

function Component:focus()
  vim.api.nvim_set_current_win(self:get_win_id())
  return self
end

function Component:clear_timers()
  if self.anim_id then
    vim.fn.timer_stop(self.anim_id)
  end
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

function Component:clear(force)
  sign.unplace(self:get_buf())
  virtual_text.clear(self:get_buf(), self:get_ns_id())
  if self:is_static() and not force then
    self:clear_timers()
    return
  end
  self:set_loading(false)
  self:set_error(false)
  self:set_lines({}, force)
  return self
end

function Component:mount()
  error('Component must implement mount method')
end

function Component:unmount()
  error('Component must implement unmount method')
end

return Component
