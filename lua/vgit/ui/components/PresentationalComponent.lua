local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local HorizontalBorderElement = require(
  'vgit.ui.elements.HorizontalBorderElement'
)
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local dimensions = require('vgit.ui.dimensions')
local Buffer = require('vgit.core.Buffer')

local PresentationalComponent = Component:extend()

function PresentationalComponent:new(options)
  return setmetatable(
    Component:new(utils.object.assign(options, {
      elements = {
        header = nil,
        horizontal_border = nil,
      },
    })),
    PresentationalComponent
  )
end

function PresentationalComponent:set_cursor(cursor)
  self.window:set_cursor(cursor)
  return self
end

function PresentationalComponent:set_lnum(lnum)
  self.window:set_lnum(lnum)
  return self
end

function PresentationalComponent:call(callback)
  self.window:call(callback)
  return self
end

function PresentationalComponent:reset_cursor()
  self.window:set_cursor({ 1, 1 })
  return self
end

function PresentationalComponent:get_dimensions(window_props)
  local is_at_cursor = window_props.relative == 'cursor'
  local global_height = dimensions.global_height()
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
  if is_at_cursor then
    local horizontal_border_height = HorizontalBorderElement:get_height()
    height = height + horizontal_border_height
    window_props.height = window_props.height - horizontal_border_height
  end

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
      col = window_props.col,
      height = height,
      width = window_props.width,
    },
  }
end

function PresentationalComponent:mount()
  if self.mounted then
    return self
  end
  local config = self.config
  local component_dimensions = self:get_dimensions(config.window_props)
  local window_props = component_dimensions.window_props
  local header_window_props = component_dimensions.header_window_props
  local horizontal_border_window_props =
    component_dimensions.horizontal_border_window_props
  local is_at_cursor = component_dimensions.is_at_cursor

  self.buffer = Buffer:new():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.window = Window
    :open(buffer, window_props)
    :assign_options(config.win_options)
  self.elements.header = HeaderElement
    :new()
    :mount(utils.object.assign(header_window_props, {
      type = 'bot',
    }))
  if is_at_cursor then
    self.elements.horizontal_border = HorizontalBorderElement
      :new()
      :mount(horizontal_border_window_props)
  end

  self.mounted = true
  self.component_dimensions = component_dimensions

  return self
end

function PresentationalComponent:unmount()
  local header = self.elements.header
  local horizontal_border = self.elements.horizontal_border
  self.window:close()
  if header then
    header:unmount()
  end
  if horizontal_border then
    horizontal_border:unmount()
  end
  return self
end

function PresentationalComponent:set_title(title, opts)
  opts = opts or {}
  local filename = opts.filename
  local filetype = opts.filetype
  local stat = opts.stat
  local header = self.elements.header
  local text = title
  if filename or filetype or stat then
    text = utils.accumulate_string(title, ': ')
  end
  local hl_range_infos = {}
  if filename then
    text = utils.accumulate_string(text, filename)
    text = utils.accumulate_string(text, ' ')
  end
  if filetype then
    local icon, icon_hl = icons.file_icon(filename, filetype)
    if icon then
      local new_text, hl_range = utils.accumulate_string(text, icon)
      text = utils.accumulate_string(new_text, ' ')
      hl_range_infos[#hl_range_infos + 1] = {
        hl = icon_hl,
        range = hl_range,
      }
    end
  end
  if stat then
    local more_added = stat.added > stat.removed
    local more_removed = stat.removed > stat.added
    local new_text, hl_range = utils.accumulate_string(
      text,
      more_added and '++' or '+'
    )
    text = new_text
    hl_range_infos[#hl_range_infos + 1] = {
      hl = 'GitSignsAdd',
      range = hl_range,
    }
    text = utils.accumulate_string(text, tostring(stat.added))
    text = utils.accumulate_string(text, ' ')
    new_text, hl_range = utils.accumulate_string(
      text,
      more_removed and '--' or '-'
    )
    text = new_text
    hl_range_infos[#hl_range_infos + 1] = {
      hl = 'GitSignsDelete',
      range = hl_range,
    }
    text = utils.accumulate_string(text, tostring(stat.removed))
  end
  header:set_lines({ text })
  for _, range_info in ipairs(hl_range_infos) do
    local hl = range_info.hl
    local range = range_info.range
    header.buffer:add_highlight(hl, 0, range.top, range.bot)
  end
  return self
end

return PresentationalComponent
