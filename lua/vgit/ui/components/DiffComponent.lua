local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local HeaderTitle = require('vgit.ui.decorations.HeaderTitle')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')
local Notification = require('vgit.ui.decorations.Notification')

local DiffComponent = Component:extend()

function DiffComponent:constructor(props)
  props = utils.object.assign({
    config = {
      elements = {
        header = true,
        footer = true,
      },
      win_plot = {
        zindex = 3,
      },
    },
  }, props)
  return Component.constructor(self, props)
end

function DiffComponent:set_cursor(cursor)
  self.window:set_cursor(cursor)
  return self
end

function DiffComponent:set_lnum(lnum)
  self.window:set_lnum(lnum)
  return self
end

function DiffComponent:call(callback)
  self.window:call(callback)
  return self
end

function DiffComponent:reset_cursor()
  Component.reset_cursor(self)
  return self
end

function DiffComponent:clear_lines()
  Component.clear_lines(self)
  return self
end

function DiffComponent:position_cursor(placement)
  Component.position_cursor(self, placement)
  return self
end

function DiffComponent:mount(opts)
  opts = opts or {}

  if self.mounted then return self end

  local config = self.config

  self.notification = Notification()
  self.header_title = HeaderTitle()
  self.buffer = Buffer():create():assign_options(config.buf_options)

  local plot = self.plot
  local buffer = self.buffer

  if config.elements.header then self.elements.header = HeaderElement():mount(plot.header_win_plot) end
  if config.elements.footer then self.elements.footer = FooterElement():mount(plot.footer_win_plot) end

  self.window = Window:open(buffer, plot.win_plot):assign_options(config.win_options)

  self.mounted = true

  return self
end

function DiffComponent:unmount()
  if not self.mounted then return self end

  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()
  if header then header:unmount() end
  if footer then footer:unmount() end

  return self
end

function DiffComponent:set_title(title, opts)
  local header = self.elements.header
  if not header then return self end

  self.header_title:set(header, title, opts)

  return self
end

function DiffComponent:clear_title()
  local header = self.elements.header
  if not header then return self end

  self.header_title:clear(header)

  return self
end

function DiffComponent:render_line_numbers(lines)
  local offset = 1
  local max_digits = string.len(tostring(#lines)) + offset

  for i = 1, #lines do
    local hl = lines[i][2]
    local text = lines[i][1]
    local text_len = string.len(text)
    if text_len < max_digits then text = string.format('%s%s', string.rep(' ', max_digits - text_len), text) end
    self:place_extmark_lnum({
      row = i - 1,
      hl = hl,
      text = text,
    })
  end

  return self
end

function DiffComponent:clear_extmarks()
  Component.clear_extmarks(self)

  local header = self.elements.header
  if header then header:clear_extmarks() end

  return self
end

function DiffComponent:clear_notification()
  local header = self.elements.header
  if not header then return self end

  self.notification:clear_notification(header)

  return self
end

function DiffComponent:notify(text)
  local header = self.elements.header
  if not header then return self end

  self.notification:notify(header, text)

  return self
end

return DiffComponent
