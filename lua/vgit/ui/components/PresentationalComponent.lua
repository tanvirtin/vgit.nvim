local icons = require('vgit.core.icons')
local ComponentPlot = require('vgit.ui.ComponentPlot')
local utils = require('vgit.core.utils')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')
local Component = require('vgit.ui.Component')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')

local PresentationalComponent = Component:extend()

function PresentationalComponent:new(props)
  return setmetatable(
    Component:new(utils.object.assign({
      config = {
        elements = {
          header = true,
          footer = true,
          line_number = false,
        },
      },
    }, props)),
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

function PresentationalComponent:mount(opts)
  if self.mounted then
    return self
  end
  opts = opts or {}
  local config = self.config
  local elements_config = config.elements

  local win_plot = config.win_plot

  local plot = ComponentPlot
    :new(win_plot, utils.object.merge(elements_config, opts))
    :build()

  self.buffer = Buffer:new():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.window = Window:open(buffer, win_plot):assign_options(config.win_options)
  self.elements.header = HeaderElement:new():mount(plot.header_win_plot)

  if elements_config.footer then
    self.elements.footer = FooterElement:new():mount(plot.footer_win_plot)
  end

  self.mounted = true
  self.plot = plot

  return self
end

function PresentationalComponent:unmount()
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

function PresentationalComponent:set_title(title, opts)
  opts = opts or {}
  local filename = opts.filename
  local filetype = opts.filetype
  local stat = opts.stat
  local header = self.elements.header
  local text = title
  if filename or filetype or stat then
    text = utils.str.concat(title, ': ')
  end
  local hl_range_infos = {}
  if filename then
    text = utils.str.concat(text, filename)
    text = utils.str.concat(text, ' ')
  end
  if filetype then
    local icon, icon_hl = icons.file_icon(filename, filetype)
    if icon then
      local new_text, hl_range = utils.str.concat(text, icon)
      text = utils.str.concat(new_text, ' ')
      hl_range_infos[#hl_range_infos + 1] = {
        hl = icon_hl,
        range = hl_range,
      }
    end
  end
  if stat then
    local more_added = stat.added > stat.removed
    local more_removed = stat.removed > stat.added
    local new_text, hl_range = utils.str.concat(
      text,
      more_added and '++' or '+'
    )
    text = new_text
    hl_range_infos[#hl_range_infos + 1] = {
      hl = 'GitSignsAdd',
      range = hl_range,
    }
    text = utils.str.concat(text, tostring(stat.added))
    text = utils.str.concat(text, ' ')
    new_text, hl_range = utils.str.concat(text, more_removed and '--' or '-')
    text = new_text
    hl_range_infos[#hl_range_infos + 1] = {
      hl = 'GitSignsDelete',
      range = hl_range,
    }
    text = utils.str.concat(text, tostring(stat.removed))
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
