local utils = require('vgit.core.utils')
local Component = require('vgit.ui.Component')
local FooterElement = require('vgit.ui.elements.FooterElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local Buffer = require('vgit.core.Buffer')
local Window = require('vgit.core.Window')
local TableGenerator = require('vgit.ui.TableGenerator')

local TableComponent = Component:extend()

function TableComponent:constructor(props)
  props = utils.object.assign({
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
      },
      win_options = {
        cursorline = true,
      },
    },
  }, props)
  return Component.constructor(self, props)
end

function TableComponent:paint(hls)
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local range = hl_info.range

    self.buffer:add_highlight({
      hl = hl,
      row = hl_info.row - 1,
      col_range = {
        from = range.top,
        to = range.bot,
      },
    })
  end

  return self
end

function TableComponent:set_lines(lines, force)
  if self.locked and not force then return self end

  local header = self.elements.header
  local buffer = self.buffer

  local labels, rows, hls =
    TableGenerator(self.config.column_labels, lines, self.column_spacing, self.column_len):generate()

  header:set_lines(labels)
  buffer:set_lines(rows)

  return self:paint(hls)
end

function TableComponent:render_rows(rows, format)
  local formatted_row = {}

  for i = 1, #rows do
    local row = rows[i]
    formatted_row[#formatted_row + 1] = format(row, i)
  end

  self:set_lines(formatted_row)

  return self
end

function TableComponent:mount()
  if self.mounted then return self end

  local config = self.config
  local plot = self.plot

  local buffer = Buffer():create():assign_options(config.buf_options)
  self.buffer = buffer
  self.window = Window:open(buffer, plot.win_plot):assign_options(config.win_options)
  self.elements.header = HeaderElement():mount(plot.header_win_plot)

  if config.elements.footer then self.elements.footer = FooterElement():mount(plot.footer_win_plot) end

  self.mounted = true

  return self
end

function TableComponent:unmount()
  if not self.mounted then return self end

  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()

  if header then header:unmount() end

  if footer then footer:unmount() end

  return self
end

return TableComponent
