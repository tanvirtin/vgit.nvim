local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local ComponentPlot = require('vgit.ui.ComponentPlot')
local symbols_setting = require('vgit.settings.symbols')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')

local FoldableListComponent = Component:extend()

function FoldableListComponent:constructor(props)
  return utils.object.assign(Component.constructor(self), {
    _cache = {},
    state = {
      list = {},
      hls = {},
    },
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
  }, props)
end

function FoldableListComponent:call(callback)
  self.window:call(callback)

  return self
end

function FoldableListComponent:set_list(list)
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
  return self._cache[lnum]
end

function FoldableListComponent:query_list_item(callback)
  for _, list_item in ipairs(self._cache) do
    local result = callback(list_item)

    if result == true then
      return list_item
    end
  end

  return nil
end

function FoldableListComponent:generate_lines()
  local spacing = 2
  local current_lnum = 0
  local foldable_list_shadow = {}
  local hls = {}

  local function generate_lines(list, depth)
    if not list then
      return
    end

    for i = 1, #list do
      local item = list[i]
      current_lnum = current_lnum + 1

      -- Memoizing recursion inside a flattened list, for O(1) memory access.
      self._cache[current_lnum] = item
      local value = item.value
      local items = item.items
      local icon_before = item.icon_before
      local icon_after = item.icon_after
      local icon_hl_range_offset = 0
      local indentation_count = spacing * depth
      local indentation = string.rep(' ', indentation_count)

      if items then
        icon_hl_range_offset = 3
      end

      if icon_before then
        value = string.format('%s %s', icon_before.icon, value)
        hls[#hls + 1] = {
          hl = icon_before.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset + 2,
            bot = indentation_count
              + icon_hl_range_offset
              + #icon_before.icon
              + 1,
          },
        }
      elseif icon_after then
        value = string.format('%s %s', value, icon_after.icon)
        hls[#hls + 1] = {
          hl = icon_after.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset + utils.str.length(
              value
            ),
            bot = indentation_count + icon_hl_range_offset + utils.str.length(
              value
            ) + #icon_after.icon,
          },
        }
      end

      if items then
        local item_count = string.format('(%s)', #items)
        local fold_symbol = symbols_setting:get(item.open and 'open' or 'close')
        local fold_header = string.format(
          '%s%s %s %s',
          indentation,
          fold_symbol,
          value,
          item_count
        )
        foldable_list_shadow[#foldable_list_shadow + 1] = fold_header
        hls[#hls + 1] = {
          hl = 'GitSymbol',
          lnum = current_lnum,
          range = {
            top = 1 + indentation_count,
            bot = 1 + indentation_count + #fold_symbol,
          },
        }
        hls[#hls + 1] = {
          hl = 'GitCount',
          lnum = current_lnum,
          range = {
            top = #fold_header - #item_count,
            bot = #fold_header,
          },
        }
        hls[#hls + 1] = {
          hl = 'GitTitle',
          lnum = current_lnum,
          range = {
            top = 1 + indentation_count + #fold_symbol,
            bot = 1 + indentation_count + #fold_symbol + #value,
          },
        }

        if item.open then
          generate_lines(items, depth + 1)
        end
      else
        foldable_list_shadow[#foldable_list_shadow + 1] = string.format(
          '%s%s',
          indentation,
          value
        )
      end
    end
  end

  generate_lines(self.state.list, 0)

  self.state.hls = hls

  return foldable_list_shadow
end

function FoldableListComponent:paint()
  local hls = self.state.hls
  local num_hls = #hls

  for i = 1, num_hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local lnum = hl_info.lnum
    local range = hl_info.range

    self.buffer:add_highlight(hl, lnum - 1, range.top, range.bot)
  end

  return self
end

function FoldableListComponent:sync()
  self.buffer:clear_namespace():set_lines(self:generate_lines())

  loop.await_fast_event()
  self:paint()
  loop.await_fast_event()

  return self
end

function FoldableListComponent:mount(opts)
  if self.mounted then
    return self
  end

  opts = opts or {}
  local config = self.config
  local elements_config = config.elements

  local plot = ComponentPlot(
    config.win_plot,
    utils.object.merge(elements_config, opts)
  ):build()

  self.buffer = Buffer():create():assign_options(config.buf_options)
  local buffer = self.buffer

  self.window = Window
    :open(buffer, plot.win_plot)
    :assign_options(config.win_options)

  if elements_config.header then
    self.elements.header = HeaderElement():mount(plot.header_win_plot)
  end

  if elements_config.footer then
    self.elements.footer = FooterElement():mount(plot.footer_win_plot)
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
