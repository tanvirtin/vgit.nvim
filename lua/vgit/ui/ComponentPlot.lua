local dimensions = require('vgit.ui.dimensions')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local LineNumberElement = require('vgit.ui.elements.LineNumberElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')

local ComponentPlot = Object:extend()

function ComponentPlot:new(win_plot, config)
  return setmetatable({
    is_built = false,
    config = config,
    win_plot = ComponentPlot:sanitize_plot(win_plot),
    header_win_plot = nil,
    line_number_win_plot = nil,
    footer_win_plot = nil,
    is_at_cursor = win_plot.relative == 'cursor',
  }, ComponentPlot)
end

-- Plots must always be sanitized.
-- Meaning attributes tossed around such as 'vh', 'vw' will be made sense here.
function ComponentPlot:sanitize_plot(plot)
  plot.row = dimensions.convert(plot.row)
  plot.col = dimensions.convert(plot.col)
  plot.height = dimensions.convert(plot.height)
  plot.width = dimensions.convert(plot.width)
  return plot
end

function ComponentPlot:configure_bounds()
  if self.is_built then
    return self
  end

  local config = self.config
  local has_line_number = config.line_number
  local has_footer = config.footer
  local footer_height = FooterElement:get_height()
  local win_plot = self.win_plot

  local global_height = dimensions.global_height()
  if win_plot.row + win_plot.height > global_height then
    if self.is_at_cursor then
      win_plot.row = win_plot.row
        - (win_plot.row + win_plot.height - global_height)
      if has_footer then
        win_plot.row = win_plot.row - footer_height
      end
    else
      win_plot.height = win_plot.height - win_plot.row
      if has_line_number then
        self.line_number_win_plot.height = win_plot.height
      end
    end
  end
  return self
end

function ComponentPlot:configure_height()
  if self.is_built then
    return self
  end

  local header_height = HeaderElement:get_height()
  local footer_height = FooterElement:get_height()
  local win_plot = self.win_plot
  local config = self.config
  local has_header = config.header
  local has_footer = config.footer
  local has_line_number = config.line_number

  -- Height
  if has_header and win_plot.height - header_height > 1 then
    win_plot.height = win_plot.height - header_height
  end
  if has_footer then
    win_plot.height = win_plot.height - footer_height
  end
  if has_line_number then
    self.line_number_win_plot.height = win_plot.height
  end
  return self
end

function ComponentPlot:configure_width()
  if self.is_built then
    return self
  end

  local win_plot = self.win_plot
  local has_line_number = self.config.line_number

  -- Width
  local line_number_width = LineNumberElement:get_width()
  if has_line_number then
    win_plot.width = win_plot.width - line_number_width
  end
  return self
end

function ComponentPlot:configure_row()
  if self.is_built then
    return self
  end

  local config = self.config
  local win_plot = self.win_plot
  local has_header = config.header
  local has_footer = config.footer
  local has_line_number = config.line_number
  local header_height = HeaderElement:get_height()
  local footer_win_plot = self.footer_win_plot

  -- Row
  if has_header then
    self.header_win_plot.row = win_plot.row + header_height
    win_plot.row = win_plot.row + header_height
  end
  if has_line_number then
    self.line_number_win_plot.row = win_plot.row
  end
  if has_footer then
    footer_win_plot.row = win_plot.row
    footer_win_plot.row = footer_win_plot.row + win_plot.height
  end
  return self
end

function ComponentPlot:configure_col()
  if self.is_built then
    return self
  end

  local win_plot = self.win_plot
  local has_line_number = self.config.line_number
  -- Col
  if has_line_number then
    local line_number_width = LineNumberElement:get_width()
    win_plot.col = win_plot.col + line_number_width
  end
  return self
end

function ComponentPlot:build()
  if self.is_built then
    return self
  end

  local win_plot = self.win_plot
  local config = self.config
  local is_at_cursor = self.is_at_cursor

  if is_at_cursor then
    win_plot.relative = 'editor'
    win_plot.row = config.winline or vim.fn.winline()
  end

  -- Element window props, these props will get modified below accordingly
  self.line_number_win_plot = utils.object.clone(win_plot)
  self.header_win_plot = utils.object.clone(win_plot)
  self.footer_win_plot = utils.object.clone(win_plot)

  self:configure_bounds():configure_height():configure_width():configure_row():configure_col().is_built =
    true

  return self
end

return ComponentPlot
