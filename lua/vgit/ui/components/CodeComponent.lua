local ComponentPlot = require('vgit.ui.ComponentPlot')
local HeaderTitle = require('vgit.ui.decorators.HeaderTitle')
local Notification = require('vgit.ui.decorators.Notification')
local utils = require('vgit.core.utils')
local LineNumberElement = require('vgit.ui.elements.LineNumberElement')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

local CodeComponent = Component:extend()

function CodeComponent:new(props)
  return setmetatable(
    Component:new(utils.object.assign({
      config = {
        elements = {
          header = true,
          line_number = true,
          footer = true,
        },
      },
    }, props)),
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

function CodeComponent:sign_unplace()
  self.buffer:sign_unplace()
  self.elements.line_number:sign_unplace()
  return self
end

function CodeComponent:sign_place_line_number(lnum, sign_name)
  self.elements.line_number:sign_place(lnum, sign_name)
  return self
end

function CodeComponent:transpose_virtual_line_number(text, hl, row)
  self.elements.line_number:transpose_virtual_line(
    { { text, hl } },
    row,
    'right_align'
  )
end

function CodeComponent:mount(opts)
  if self.mounted then
    return self
  end
  opts = opts or {}
  local config = self.config
  local elements_config = config.elements

  local plot = ComponentPlot
    :new(config.win_plot, utils.object.merge(elements_config, opts))
    :build()

  self.notification = Notification:new()
  self.header_title = HeaderTitle:new()
  self.buffer = Buffer:new():create():assign_options(config.buf_options)

  local buffer = self.buffer

  self.elements.line_number = LineNumberElement
    :new()
    :mount(plot.line_number_win_plot)

  if elements_config.header then
    self.elements.header = HeaderElement:new():mount(plot.header_win_plot)
  end

  if elements_config.footer then
    self.elements.footer = FooterElement:new():mount(plot.footer_win_plot)
  end

  self.window = Window
    :open(buffer, plot.win_plot)
    :assign_options(config.win_options)

  self.mounted = true
  self.plot = plot

  return self
end

function CodeComponent:unmount()
  local header = self.elements.header
  local line_number = self.elements.line_number
  local footer = self.elements.footer
  self.window:close()
  if header then
    header:unmount()
  end
  if line_number then
    line_number:unmount()
  end
  if footer then
    footer:unmount()
  end
  return self
end

function CodeComponent:set_title(title, opts)
  local header = self.elements.header
  if not header then
    return self
  end
  self.header_title:set(header, title, opts)
  return self
end

function CodeComponent:make_line_numbers(lines)
  local line_number = self.elements.line_number
  line_number:clear_namespace()
  line_number:set_lines(lines)
  return self
end

function CodeComponent:notify(text)
  local header = self.elements.header
  if not header then
    return self
  end
  self.notification:notify(header, text)
  return self
end

return CodeComponent
