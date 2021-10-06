local Component = require('vgit.Component')
local Interface = require('vgit.Interface')
local buffer = require('vgit.buffer')
local AppBarDecorator = require('vgit.decorators.AppBarDecorator')

local function shorten_str(str, limit)
  if #str > limit then
    str = str:sub(1, limit - 3)
    str = str .. '...'
  end
  return str
end

local function make_paddings(
  rows,
  column_labels,
  column_spacing,
  max_column_len
)
  local padding = {}
  for i = 1, #rows do
    local items = rows[i]
    assert(
      #column_labels == #items,
      'number of columns should be the same as number of column_labels'
    )
    for j = 1, #items do
      local value = shorten_str(items[j], max_column_len)
      if padding[j] then
        padding[j] = math.max(padding[j], #value + column_spacing)
      else
        padding[j] = column_spacing + #value + column_spacing
      end
    end
  end
  return padding
end

local function make_heading(
  paddings,
  column_labels,
  column_spacing,
  max_column_len
)
  local row = string.format('%s', string.rep(' ', column_spacing))
  for i = 1, #column_labels do
    local label = shorten_str(column_labels[i], max_column_len)
    row = string.format(
      '%s%s%s',
      row,
      label,
      string.rep(' ', paddings[i] - #label)
    )
  end
  return { row }
end

local function make(rows, paddings, column_spacing, max_column_len)
  local lines = {}
  for i = 1, #rows do
    local row = string.format('%s', string.rep(' ', column_spacing))
    local items = rows[i]
    for j = 1, #items do
      local value = shorten_str(items[j], max_column_len)
      row = string.format(
        '%s%s%s',
        row,
        value,
        string.rep(' ', paddings[j] - #value)
      )
    end
    lines[#lines + 1] = row
  end
  return lines
end

local TableComponent = Component:extend()

function TableComponent:new(options)
  assert(
    options == nil or type(options) == 'table',
    'type error :: expected table or nil'
  )
  options = options or {}
  local height = self:get_min_height()
  local width = self:get_min_width()
  return setmetatable({
    anim_id = nil,
    state = {
      buf = nil,
      win_id = nil,
      ns_id = nil,
      border = nil,
      header = nil,
      loading = false,
      error = false,
      mounted = false,
      paddings = {},
      cache = {
        lines = {},
        cursor = nil,
      },
      paint_count = 0,
    },
    config = Interface
      :new({
        filetype = '',
        header = {},
        column_spacing = 10,
        max_column_len = 40,
        border = {
          enabled = false,
          title = '',
          footer = '',
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
        },
        static = false,
      })
      :assign(options),
  }, TableComponent)
end

function TableComponent:get_header_buf()
  return self:get_header() and self:get_header():get_buf() or nil
end

function TableComponent:get_header_win_id()
  return self:get_header() and self:get_header():get_win_id() or nil
end

function TableComponent:get_header()
  return self.state.header
end

function TableComponent:get_paddings()
  return self.state.paddings
end

function TableComponent:get_column_spacing()
  return self.config:get('column_spacing')
end

function TableComponent:get_column_ranges()
  local column_ranges = {}
  local paddings = self:get_paddings()
  local last_range = nil
  for i = 1, #paddings do
    if i == 1 then
      column_ranges[#column_ranges + 1] = { 0, paddings[i] }
    else
      column_ranges[#column_ranges + 1] = {
        last_range[2],
        last_range[2] + paddings[i],
      }
    end
    last_range = column_ranges[#column_ranges]
  end
  return column_ranges
end

function TableComponent:set_paddings(paddings)
  assert(type(paddings) == 'table', 'type error :: expected table')
  self.state.paddings = paddings
  return self
end

function TableComponent:set_header(header)
  assert(type(header) == 'table', 'type error :: expected table')
  self.state.header = header
  return self
end

function TableComponent:set_lines(lines, force)
  if self:is_static() and self:has_lines() and not force then
    return self
  end
  assert(type(lines) == 'table', 'type error :: expected table')
  self:increment_paint_count()
  self:clear_timers()
  local header = self.config:get('header')
  local column_spacing = self.config:get('column_spacing')
  local max_column_len = self.config:get('max_column_len')
  local paddings = make_paddings(lines, header, column_spacing, max_column_len)
  local column_header = make_heading(
    paddings,
    header,
    column_spacing,
    max_column_len
  )
  local rows = make(lines, paddings, column_spacing, max_column_len)
  buffer.set_lines(self:get_buf(), rows)
  self:get_header():set_lines(column_header)
  self:set_paddings(paddings)
  return self
end

function TableComponent:mount()
  if self:is_mounted() then
    return self
  end
  local buf_options = self.config:get('buf_options')
  local border_config = self.config:get('border')
  local window_props = self.config:get('window_props')
  local win_options = self.config:get('win_options')
  self:set_buf(vim.api.nvim_create_buf(false, true))
  local buf = self:get_buf()
  buffer.assign_options(buf, buf_options)
  local win_ids = {}
  if self:is_border_enabled() then
    window_props.border = self:make_border(border_config)
  end
  self:set_header(AppBarDecorator:new(window_props, buf):mount())
  -- Correct addition of header decorator parameters.
  window_props.row = window_props.row + 3
  if window_props.height - 3 > 1 then
    window_props.height = window_props.height - 3
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
  win_ids[#win_ids + 1] = win_id
  self:on(
    'BufWinLeave',
    string.format(':lua require("vgit").renderer.hide_windows(%s)', win_ids)
  )
  self:add_syntax_highlights()
  self:set_mounted(true)
  return self
end

function TableComponent:unmount()
  self:set_mounted(false)
  local win_id = self:get_win_id()
  if vim.api.nvim_win_is_valid(win_id) then
    self:clear()
    pcall(vim.api.nvim_win_close, win_id, true)
  end
  local header_win_id = self:get_header_win_id()
  if vim.api.nvim_win_is_valid(header_win_id) then
    pcall(vim.api.nvim_win_close, header_win_id, true)
  end
  return self
end

return TableComponent
