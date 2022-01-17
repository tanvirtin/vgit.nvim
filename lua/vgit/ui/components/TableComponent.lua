local ComponentPlot = require('vgit.ui.ComponentPlot')
local utils = require('vgit.core.utils')
local Component = require('vgit.ui.Component')
local table_maker = require('vgit.ui.formatter.table_maker')
local FooterElement = require('vgit.ui.elements.FooterElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')

local TableComponent = Component:extend()

function TableComponent:new(props)
  props = props or {}
  return setmetatable(
    Component:new(utils.object.assign({
      column_spacing = 3,
      max_column_len = 80,
      paddings = {},
      elements = {
        header = nil,
        footer = nil,
      },
      config = {
        elements = {
          header = true,
          footer = true,
          line_number = false,
        },
        win_options = {
          cursorline = true,
        },
      },
    }, props)),
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

function TableComponent:paint_table(hls)
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local range = hl_info.range
    self.buffer:add_highlight(hl, hl_info.row - 1, range.top, range.bot)
  end
end

function TableComponent:set_lines(lines, force)
  if self.locked and not force then
    return self
  end
  local buffer = self.buffer
  local column_spacing = self.column_spacing
  local max_column_len = self.max_column_len
  local header = self.config.header
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

function TableComponent:mount(opts)
  if self.mounted then
    return self
  end
  local config = self.config
  local elements_config = config.elements

  local plot = ComponentPlot
    :new(config.win_plot, utils.object.merge(elements_config, opts))
    :build()

  self.buffer = Buffer:new():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.window = Window
    :open(buffer, plot.win_plot)
    :assign_options(config.win_options)
  self.elements.header = HeaderElement:new():mount(plot.header_win_plot)

  if elements_config.footer then
    self.elements.footer = FooterElement:new():mount(plot.footer_win_plot)
  end

  self.mounted = true
  self.plot = plot

  return self
end

function TableComponent:unmount()
  local header = self.elements.header
  local footer = self.elements.footer
  self.window:close()
  if header then
    header:unmount()
  end
  if footer then
    footer:unmount()
  end
end

return TableComponent
