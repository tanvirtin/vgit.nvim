local ComponentPlot = require('vgit.ui.ComponentPlot')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')
local Component = require('vgit.ui.Component')

local function generate_lines(list, depth, accumulator)
  local spacing = 2
  for i = 1, #list do
    local item = list[i]
    if item.items then
      accumulator[#accumulator + 1] = string.format(
        '%s%s (%s)',
        string.rep(' ', spacing * depth),
        item.value,
        #item.items
      )
      if item.open then
        generate_lines(item.items, depth + 1, accumulator)
      end
    else
      accumulator[#accumulator + 1] = string.format(
        '%s%s',
        string.rep(' ', spacing * depth),
        item.value
      )
    end
  end
  return accumulator
end

local function find_in_list(list, lnum, running_lnum)
  running_lnum = running_lnum or 0
  for i = 1, #list do
    running_lnum = running_lnum + 1
    local item = list[i]
    if item.items then
      if item.open then
        if running_lnum == lnum then
          return item
        else
          local found_item, found_lnum = find_in_list(
            item.items,
            lnum,
            running_lnum
          )
          running_lnum = found_lnum
          if found_item then
            return found_item, running_lnum
          end
        end
      else
        if running_lnum == lnum then
          return item, running_lnum
        end
      end
    else
      if running_lnum == lnum then
        return item, running_lnum
      end
    end
  end
  return nil, running_lnum
end

local FoldableListComponent = Component:extend()

function FoldableListComponent:new(props)
  return setmetatable(
    Component:new(utils.object.assign({
      config = {
        elements = {
          header = true,
          footer = true,
          line_number = false,
        },
      },
      elements = {
        header = nil,
        footer = nil,
      },
    }, props)),
    FoldableListComponent
  )
end

function FoldableListComponent:call(callback)
  self.window:call(callback)
  return self
end

function FoldableListComponent:define(list)
  self.state.list = list
  return self
end

function FoldableListComponent:toggle_list_item(item)
  if item.items then
    item.open = not item.open
  end
  return self
end

function FoldableListComponent:is_fold(item)
  return item and item.items and #item.items > 0
end

function FoldableListComponent:get_list_item(lnum)
  return find_in_list(self.state.list, lnum)
end

function FoldableListComponent:render()
  local buffer = self.buffer
  buffer:clear_namespace():set_lines(generate_lines(self.state.list, 0, {}))
  return self
end

function FoldableListComponent:mount(opts)
  if self.mounted then
    return self
  end
  opts = opts or {}
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

  if elements_config.header then
    self.elements.header = HeaderElement:new():mount(plot.header_win_plot)
  end

  if elements_config.footer then
    self.elements.footer = FooterElement:new():mount(plot.footer_win_plot)
  end

  self.mounted = true
  self.plot = plot

  return self
end

function FoldableListComponent:unmount()
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

return FoldableListComponent
