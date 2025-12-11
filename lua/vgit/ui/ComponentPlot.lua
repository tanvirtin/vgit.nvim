local dimensions = require('vgit.ui.dimensions')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local header_element_height = 1
local footer_element_height = 1

local ComponentPlot = Object:extend()

function ComponentPlot:constructor(win_plot, config)
  return {
    is_built = false,
    config = config,
    win_plot = ComponentPlot:sanitize_plot(win_plot),
    header_win_plot = nil,
    footer_win_plot = nil,
    is_at_cursor = win_plot.relative == 'cursor',
  }
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
  if self.is_built then return self end

  local config = self.config
  local has_footer = config.footer
  local win_plot = self.win_plot
  local global_height = dimensions.global_height()

  if win_plot.row + win_plot.height > global_height then
    if self.is_at_cursor then
      win_plot.row = win_plot.row - (win_plot.row + win_plot.height - global_height)

      if has_footer then win_plot.row = win_plot.row - footer_element_height end
    else
      -- Calculate height to fill from current row to bottom of screen
      -- The +1 compensates for the off-by-one when row > 0
      local height = win_plot.height - win_plot.row + 1

      if height > 0 then win_plot.height = height end
    end
  end

  return self
end

function ComponentPlot:configure_height()
  if self.is_built then return self end

  local win_plot = self.win_plot
  local config = self.config
  local has_header = config.header
  local has_footer = config.footer

  -- Height
  if has_header then
    self.header_win_plot.height = header_element_height
    if win_plot.height - header_element_height > 1 then win_plot.height = win_plot.height - header_element_height end
  end

  if has_footer then
    win_plot.height = win_plot.height - footer_element_height
    self.footer_win_plot.height = footer_element_height
  end

  return self
end

function ComponentPlot:configure_width()
  if self.is_built then return self end

  return self
end

function ComponentPlot:configure_row()
  if self.is_built then return self end

  local config = self.config
  local win_plot = self.win_plot
  local has_header = config.header
  local has_footer = config.footer
  local footer_win_plot = self.footer_win_plot

  -- Row: Position header at current row, push content down by header height
  if has_header then
    self.header_win_plot.row = win_plot.row
    win_plot.row = win_plot.row + header_element_height
  end

  if has_footer then footer_win_plot.row = win_plot.row + win_plot.height end

  return self
end

function ComponentPlot:configure_col()
  if self.is_built then return self end

  return self
end

function ComponentPlot:build()
  if self.is_built then return self end

  local win_plot = self.win_plot
  local is_at_cursor = self.is_at_cursor

  if is_at_cursor then
    win_plot.relative = 'editor'
    win_plot.row = vim.fn.winline()
  end

  -- Element window props, these props will get modified below accordingly
  local has_header = self.config.header
  local has_footer = self.config.footer

  if has_header then self.header_win_plot = utils.object.clone(win_plot) end

  if has_footer then self.footer_win_plot = utils.object.clone(win_plot) end
  self:configure_bounds():configure_height():configure_width():configure_row():configure_col()

  self.is_built = true

  return self
end

return ComponentPlot
