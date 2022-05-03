local ComponentPlot = require('vgit.ui.ComponentPlot')
local utils = require('vgit.core.utils')
local Component = require('vgit.ui.Component')
local FooterElement = require('vgit.ui.elements.FooterElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local table_maker = require('vgit.ui.components.TableComponent.table_maker')

local TableComponent = Component:extend()

function TableComponent:constructor(props)
  return utils.object.assign(Component.constructor(self), {
    column_len = 80,
    column_spacing = 3,
    elements = {
      header = nil,
      footer = nil,
    },
    config = {
      column_labels = {},
      elements = {
        header = true,
        footer = true,
        line_number = false,
      },
      win_options = {
        cursorline = true,
      },
    },
  }, props)
end

function TableComponent:paint(hls)
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local range = hl_info.range

    self.buffer:add_highlight(hl, hl_info.row - 1, range.top, range.bot)
  end

  return self
end

function TableComponent:set_lines(lines, force)
  if self.locked and not force then
    return self
  end

  local header = self.elements.header
  local buffer = self.buffer

  local column_labels, rows, hls = table_maker.make(
    lines,
    self.config.column_labels,
    self.column_spacing,
    self.column_len
  )

  header:set_lines(column_labels)
  buffer:set_lines(rows)
  self:paint(hls)

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

  local plot = ComponentPlot(
    config.win_plot,
    utils.object.merge(elements_config, opts)
  ):build()

  local buffer = Buffer():create():assign_options(config.buf_options)
  self.buffer = buffer
  self.window = Window
    :open(buffer, plot.win_plot)
    :assign_options(config.win_options)
  self.elements.header = HeaderElement():mount(plot.header_win_plot)

  if elements_config.footer then
    self.elements.footer = FooterElement():mount(plot.footer_win_plot)
  end

  self.mounted = true
  self.plot = plot

  return self
end

function TableComponent:unmount()
  if not self.mounted then
    return self
  end

  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()

  if header then
    header:unmount()
  end

  if footer then
    footer:unmount()
  end

  return self
end

return TableComponent
