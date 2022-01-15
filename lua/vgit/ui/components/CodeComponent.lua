local loop = require('vgit.core.loop')
local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local LineNumberElement = require('vgit.ui.elements.LineNumberElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local HorizontalBorderElement = require(
  'vgit.ui.elements.HorizontalBorderElement'
)
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local dimensions = require('vgit.ui.dimensions')
local Buffer = require('vgit.core.Buffer')

local CodeComponent = Component:extend()

function CodeComponent:new(options)
  return setmetatable(
    Component:new(utils.object.assign(options, {
      elements = {
        header = nil,
        line_number = nil,
        horizontal_border = nil,
      },
    })),
    CodeComponent
  )
end

function CodeComponent:set_cursor(cursor)
  self.window:set_cursor(cursor)
  self.elements.line_number:set_cursor(cursor)
  return self
end

function CodeComponent:set_lnum(lnum)
  self.elements.line_number:set_lnum(lnum)
  self.window:set_lnum(lnum)
  return self
end

function CodeComponent:call(callback)
  self.window:call(callback)
  self.elements.line_number:call(callback)
  return self
end

function CodeComponent:reset_cursor()
  self.window:set_cursor({ 1, 1 })
  self.elements.line_number:reset_cursor()
  return self
end

function CodeComponent:add_highlight(hl, row, col_top, col_end)
  self.buffer:add_highlight(hl, row, col_top, col_end)
  return self
end

function CodeComponent:sign_place(lnum, sign_name)
  self.buffer:sign_place(lnum, sign_name)
  return self
end

function CodeComponent:sign_place_line_number(lnum, sign_name)
  self.elements.line_number:sign_place(lnum, sign_name)
  return self
end

function CodeComponent:sign_unplace()
  self.buffer:sign_unplace()
  self.elements.line_number:sign_unplace()
  return self
end

function CodeComponent:transpose_virtual_text(text, hl, row, col, pos)
  self.buffer:transpose_virtual_text(text, hl, row, col, pos)
  return self
end

function CodeComponent:transpose_virtual_line(texts, col, pos)
  self.buffer:transpose_virtual_line(texts, col, pos)
  return self
end

function CodeComponent:transpose_virtual_line_number(text, hl, row)
  self.elements.line_number:transpose_virtual_line(
    { { text, hl } },
    row,
    'right_align'
  )
end

function CodeComponent:clear_namespace()
  self.buffer:clear_namespace()
  return self
end

function CodeComponent:get_dimensions(window_props, opts)
  local is_at_cursor = window_props.relative == 'cursor'
  local global_height = dimensions.global_height()
  -- Element window props, these props will get modified below accordingly
  local header_window_props = {
    row = window_props.row,
    col = window_props.col,
    width = window_props.width,
  }
  local line_number_window_props = {
    row = window_props.row,
    col = window_props.col,
    height = window_props.height,
  }
  local horizontal_border_window_props = {
    row = window_props.row,
    col = window_props.col,
    width = window_props.width,
  }

  if is_at_cursor then
    window_props.relative = 'editor'
    window_props.row = opts.winline or vim.fn.winline()
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
    line_number_window_props.height = line_number_window_props.height
      - header_height
  end
  local height = header_height + window_props.height
  if is_at_cursor then
    local horizontal_border_height = HorizontalBorderElement:get_height()
    height = height + horizontal_border_height
    window_props.height = window_props.height - horizontal_border_height
    line_number_window_props.height = line_number_window_props.height
      - horizontal_border_height
  end

  -- Width
  local line_number_width = LineNumberElement:get_width()
  window_props.width = window_props.width - line_number_width
  local width = line_number_width + window_props.width

  -- Row
  window_props.row = window_props.row + header_height
  line_number_window_props.row = window_props.row
  horizontal_border_window_props.row = window_props.row
  horizontal_border_window_props.row = horizontal_border_window_props.row
    + window_props.height

  -- Col
  window_props.col = window_props.col + line_number_width

  return {
    is_at_cursor = is_at_cursor,
    window_props = window_props,
    header_window_props = header_window_props,
    line_number_window_props = line_number_window_props,
    horizontal_border_window_props = horizontal_border_window_props,
    global_window_props = {
      row = header_window_props.row,
      col = line_number_window_props.col,
      height = height,
      width = width,
    },
  }
end

function CodeComponent:mount(opts)
  if self.mounted then
    return self
  end
  opts = opts or {}
  local config = self.config
  local component_dimensions = self:get_dimensions(config.window_props, opts)
  local window_props = component_dimensions.window_props
  local header_window_props = component_dimensions.header_window_props
  local line_number_window_props = component_dimensions.line_number_window_props
  local horizontal_border_window_props =
    component_dimensions.horizontal_border_window_props
  local is_at_cursor = component_dimensions.is_at_cursor

  self.buffer = Buffer:new():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.elements.line_number = LineNumberElement
    :new()
    :mount(line_number_window_props)

  self.elements.header = HeaderElement
    :new()
    :mount(utils.object.assign(header_window_props, {
      type = is_at_cursor and 'topbottom' or 'bot',
    }))

  if is_at_cursor then
    self.elements.horizontal_border = HorizontalBorderElement
      :new()
      :mount(horizontal_border_window_props)
  end

  self.window = Window
    :open(buffer, window_props)
    :assign_options(config.win_options)

  self.mounted = true
  self.component_dimensions = component_dimensions

  return self
end

function CodeComponent:unmount()
  local header = self.elements.header
  local line_number = self.elements.line_number
  local horizontal_border = self.elements.horizontal_border
  self.window:close()
  if header then
    header:unmount()
  end
  if line_number then
    line_number:unmount()
  end
  if horizontal_border then
    horizontal_border:unmount()
  end
  return self
end

function CodeComponent:set_title(title, opts)
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
    header:add_highlight(hl, 0, range.top, range.bot)
  end
  return self
end

function CodeComponent:make_line_numbers(lines)
  local line_number = self.elements.line_number
  line_number:clear_namespace()
  line_number:make_lines(lines)
  return self
end

function CodeComponent:clear_timer()
  if self.timer_id then
    vim.fn.timer_stop(self.timer_id)
    self.timer_id = nil
  end
end

function CodeComponent:notify(text)
  local epoch = 2000
  local header = self.elements.header
  self:clear_timer()
  header:notify(text)
  self.timer_id = vim.fn.timer_start(
    epoch,
    loop.async(function()
      if self.buffer:is_valid() then
        header:clear_notification()
      end
      self:clear_timer()
    end)
  )
  return self
end

return CodeComponent
