local utils = require('vgit.core.utils')
local Component = require('vgit.ui.Component')
local dimensions = require('vgit.ui.dimensions')
local table_maker = require('vgit.ui.table_maker')
local HorizontalBorderElement = require(
  'vgit.ui.elements.HorizontalBorderElement'
)
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local TableComponent = Component:extend()

function TableComponent:new(options)
  options = options or {}
  return setmetatable(
    Component:new(utils.object_assign(options, {
      column_spacing = 3,
      max_column_len = 80,
      paddings = {},
      elements = {
        header = nil,
        horizontal_border = nil,
      },
      config = {
        win_options = {
          cursorline = true,
        },
      },
    })),
    TableComponent
  )
end

function TableComponent:get_column_ranges()
  local column_ranges = {}
  local paddings = self.paddings
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

function TableComponent:get_dimensions(window_props)
  local global_height = dimensions.global_height()
  local is_at_cursor = window_props.relative == 'cursor'

  -- Element window props, these props will get modified below accordingly
  local header_window_props = {
    row = window_props.row,
    col = window_props.col,
    width = window_props.width,
  }
  local horizontal_border_window_props = {
    row = window_props.row,
    col = window_props.col,
    width = window_props.width,
  }

  if is_at_cursor then
    window_props.relative = 'editor'
    window_props.row = vim.fn.screenrow()
    header_window_props.row = window_props.row
  end

  if window_props.row + window_props.height >= global_height then
    window_props.row = window_props.row
      - (window_props.row + window_props.height - global_height)
    header_window_props.row = window_props.row
    if is_at_cursor then
      local horizontal_border_height = HorizontalBorderElement:get_height()
      window_props.row = window_props.row - horizontal_border_height
      header_window_props.row = window_props.row
    end
  end

  -- Height
  local header_height = HeaderElement:get_height()
  if window_props.height - header_height > 1 then
    window_props.height = window_props.height - header_height
  end
  local height = header_height + window_props.height

  -- Row
  window_props.row = window_props.row + header_height
  horizontal_border_window_props.row = window_props.row
  horizontal_border_window_props.row = horizontal_border_window_props.row
    + window_props.height

  return {
    is_at_cursor = is_at_cursor,
    window_props = window_props,
    header_window_props = header_window_props,
    horizontal_border_window_props = horizontal_border_window_props,
    global_window_props = {
      row = header_window_props.row,
      column = window_props.column,
      height = height,
      width = window_props.width,
    },
  }
end

function TableComponent:paint_table(hls)
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local range = hl_info.range
    self.buffer:add_highlight(hl, hl_info.row - 1, range.start, range.finish)
  end
end

function TableComponent:set_lines(lines, force)
  if self.locked and not force then
    return self
  end
  local buffer = self.buffer
  local column_spacing = self.column_spacing
  local max_column_len = self.max_column_len
  local header = self.header
  local paddings = table_maker.make_paddings(
    lines,
    header,
    column_spacing,
    max_column_len
  )
  local column_header, _ = table_maker.make_heading(
    header,
    paddings,
    column_spacing,
    max_column_len
  )
  local rows, hls = table_maker.make_rows(
    lines,
    paddings,
    column_spacing,
    max_column_len
  )
  buffer:set_lines(rows)
  self:paint_table(hls)
  self.elements.header:set_lines(column_header)
  self.paddings = paddings
  return self
end

function TableComponent:make_rows(rows, format)
  local formatted_row = {}
  for i = 1, #rows do
    local row = rows[i]
    formatted_row[#formatted_row + 1] = format(row, i)
  end
  self:set_lines(formatted_row)
  return self
end

function TableComponent:mount()
  if self.mounted then
    return self
  end
  local config = self.config
  local component_dimensions = self:get_dimensions(config.window_props)
  local is_at_cursor = component_dimensions.is_at_cursor
  local window_props = component_dimensions.window_props
  local header_window_props = component_dimensions.header_window_props
  local horizontal_border_window_props =
    component_dimensions.horizontal_border_window_props

  self.buffer = Buffer:new():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.window = Window
    :open(buffer, window_props)
    :assign_options(config.win_options)
  self.elements.header = HeaderElement:new():mount(header_window_props)
  if is_at_cursor then
    self.elements.horizontal_border = HorizontalBorderElement
      :new()
      :mount(horizontal_border_window_props)
  end

  self.mounted = true
  self.component_dimensions = component_dimensions

  return self
end

function TableComponent:unmount()
  local header = self.elements.header
  local horizontal_border = self.elements.horizontal_border
  self.window:close()
  if header then
    header:unmount()
  end
  if horizontal_border then
    horizontal_border:unmount()
  end
end

return TableComponent
