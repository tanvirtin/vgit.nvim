local Component = require('vgit.Component')
local Interface = require('vgit.Interface')
local icons = require('vgit.icons')
local buffer = require('vgit.buffer')
local VirtualLineNrDecorator = require('vgit.decorators.VirtualLineNrDecorator')
local AppBarDecorator = require('vgit.decorators.AppBarDecorator')
local render_store = require('vgit.stores.render_store')

local CodeComponent = Component:extend()

function CodeComponent:new(options)
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
        header = {
          enabled = true,
        },
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
          zindex = 60,
        },
        virtual_line_nr = {
          enabled = false,
          width = render_store.get('preview').virtual_line_nr_width,
        },
        static = false,
      })
      :assign(options),
  }, CodeComponent)
end

function CodeComponent:get_header_buf()
  return self:get_header() and self:get_header():get_buf() or nil
end

function CodeComponent:get_header_win_id()
  return self:get_header() and self:get_header():get_win_id() or nil
end

function CodeComponent:get_header()
  return self.state.header
end

function CodeComponent:is_header_enabled()
  return self.config:get('header').enabled
end

function CodeComponent:set_header(header)
  assert(type(header) == 'table', 'type error :: expected table')
  self.state.header = header
  return self
end

function CodeComponent:set_title(title, filename, filetype)
  if not self:is_header_enabled() then
    return self
  end
  local icon, icon_hl = icons.file_icon(filename, filetype)
  local header = self:get_header()
  if title == '' then
    header:set_lines({ string.format('%s %s', icon, filename) })
  else
    header:set_lines({ string.format('%s %s %s', title, icon, filename) })
  end
  if icon_hl then
    if title == '' then
      vim.api.nvim_buf_add_highlight(header:get_buf(), -1, icon_hl, 0, 0, #icon)
    else
      vim.api.nvim_buf_add_highlight(
        header:get_buf(),
        -1,
        icon_hl,
        0,
        #title + 1,
        #title + 1 + #icon
      )
    end
  end
  return self
end

function CodeComponent:notify(text)
  if not self:is_header_enabled() then
    return self
  end
  local epoch = 2000
  local header = self:get_header()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end
  header:transpose_text({ text, 'Comment' }, 0, 0, 'eol')
  self.timer_id = vim.fn.timer_start(epoch, function()
    if buffer.is_valid(header:get_buf()) then
      header:clear_ns_id()
    end
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end)
  return self
end

function CodeComponent:mount()
  if self:is_mounted() then
    return self
  end
  local buf_options = self.config:get('buf_options')
  local window_props = self.config:get('window_props')
  local win_options = self.config:get('win_options')
  self:set_buf(vim.api.nvim_create_buf(false, true))
  local buf = self:get_buf()
  buffer.assign_options(buf, buf_options)
  local win_ids = {}
  if self:is_virtual_line_nr_enabled() then
    local virtual_line_nr_config = self.config:get('virtual_line_nr')
    if self:is_header_enabled() then
      self:set_header(AppBarDecorator:new(window_props, buf):mount())
    end
    self:set_virtual_line_nr(
      VirtualLineNrDecorator:new(virtual_line_nr_config, window_props, buf)
    )
    local virtual_line_nr = self:get_virtual_line_nr()
    virtual_line_nr:mount()
    window_props.width = window_props.width - virtual_line_nr_config.width
    window_props.col = window_props.col + virtual_line_nr_config.width
    win_ids[#win_ids + 1] = virtual_line_nr:get_win_id()
  else
    if self:is_header_enabled() then
      self:set_header(AppBarDecorator:new(window_props, buf):mount())
    end
  end
  if self:is_border_enabled() then
    local border_config = self.config:get('border')
    window_props.border = self:make_border(border_config)
  end
  if self:is_header_enabled() then
    -- Correct addition of header decorator parameters.
    window_props.row = window_props.row + 3
    if window_props.height - 3 > 1 then
      window_props.height = window_props.height - 3
    end
  end
  local win_id = vim.api.nvim_open_win(buf, true, window_props)
  for key, value in pairs(win_options) do
    vim.api.nvim_win_set_option(win_id, key, value)
  end
  self:set_win_id(win_id)
  self:set_ns_id(
    vim.api.nvim_create_namespace(
      string.format('tanvirtin/vgit.nvim/%s/%s', buf, win_id)
    )
  )
  if self:is_virtual_line_nr_enabled() then
    local virtual_line_nr_config = self.config:get('virtual_line_nr')
    window_props.width = window_props.width + virtual_line_nr_config.width
    window_props.col = window_props.col - virtual_line_nr_config.width
  end
  win_ids[#win_ids + 1] = win_id
  self:on(
    'BufWinLeave',
    string.format(':lua require("vgit").renderer.hide_windows(%s)', win_ids)
  )
  self:add_syntax_highlights()
  self:set_mounted(true)
  return self
end

function CodeComponent:unmount()
  self:set_mounted(false)
  local win_id = self:get_win_id()
  if vim.api.nvim_win_is_valid(win_id) then
    self:clear()
    pcall(vim.api.nvim_win_close, win_id, true)
  end
  if self:has_virtual_line_nr() then
    local virtual_line_nr_win_id = self:get_virtual_line_nr_win_id()
    if
      virtual_line_nr_win_id
      and vim.api.nvim_win_is_valid(virtual_line_nr_win_id)
    then
      pcall(vim.api.nvim_win_close, virtual_line_nr_win_id, true)
    end
  end
  if self.config:get('header').enabled then
    local header_win_id = self:get_header_win_id()
    if vim.api.nvim_win_is_valid(header_win_id) then
      pcall(vim.api.nvim_win_close, header_win_id, true)
    end
  end
  return self
end

return CodeComponent
