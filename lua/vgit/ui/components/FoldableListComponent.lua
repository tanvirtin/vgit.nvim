local loop = require('vgit.core.loop')
local utils = require('vgit.core.utils')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local Component = require('vgit.ui.Component')
local symbols_setting = require('vgit.settings.symbols')
local HeaderElement = require('vgit.ui.elements.HeaderElement')
local FooterElement = require('vgit.ui.elements.FooterElement')

local FoldableListComponent = Component:extend()

function FoldableListComponent:constructor(props)
  props = utils.object.assign({
    state = {
      list = {},
      hls = {},
    },
    config = {
      elements = {
        header = true,
        footer = true,
      },
    },
    elements = {
      header = nil,
      footer = nil,
    },
  }, props)
  return Component.constructor(self, props)
end

function FoldableListComponent:call(callback)
  self.window:call(callback)

  return self
end

function FoldableListComponent:set_list(list)
  self.state.list = list

  return self
end

function FoldableListComponent:set_title(text)
  if self.elements.header then self.elements.header:set_lines({ text }) end

  return self
end

function FoldableListComponent:toggle_list_item(item)
  if item.items then item.open = not item.open end

  return self
end

function FoldableListComponent:is_fold(item)
  return item and item.items and #item.items > 0
end

function FoldableListComponent:get_list_item(lnum)
  return self.state[lnum]
end

function FoldableListComponent:find_list_item(callback)
  for lnum, item in pairs(self.state) do
    if callback(item) then return item, lnum end
  end
end

function FoldableListComponent:query_list_item(callback)
  for _, list_item in ipairs(self.state) do
    local result = callback(list_item)
    if result == true then return list_item end
  end
end

function FoldableListComponent:generate_lines()
  local spacing = 1
  local current_lnum = 0

  local hls = {}
  local virtual_texts = {}
  local foldable_list_shadow = {}

  local function generate_lines(list, depth)
    if not list then return end

    for i = 1, #list do
      local item = list[i]
      current_lnum = current_lnum + 1

      -- Memoizing recursion inside a flattened list, for O(1) memory access.
      self.state[current_lnum] = item

      local value = item.value
      local items = item.items
      local icon_before = item.icon_before
      local icon_after = item.icon_after
      local icon_hl_range_offset = 0

      if items then spacing = 2 end

      local indentation_count = spacing * depth

      if items then icon_hl_range_offset = 3 end

      if item.virtual_text then
        -- TODO: add other support right now just use before
        virtual_texts[#virtual_texts + 1] = {
          type = 'before',
          hl = item.virtual_text.before.hl,
          lnum = current_lnum,
          text = item.virtual_text.before.text,
        }
        indentation_count = indentation_count + 1
      end

      local indentation = string.rep(' ', indentation_count)

      if icon_before then
        if type(icon_before) == 'function' then icon_before = icon_before(item) end

        value = string.format('%s %s', icon_before.icon, value)
        hls[#hls + 1] = {
          hl = icon_before.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset + 2,
            bot = indentation_count + icon_hl_range_offset + #icon_before.icon + 1,
          },
        }
      elseif icon_after then
        if type(icon_after) == 'function' then icon_after = icon_after(item) end

        value = string.format('%s %s', value, icon_after.icon)
        hls[#hls + 1] = {
          hl = icon_after.hl,
          lnum = current_lnum,
          range = {
            top = indentation_count + icon_hl_range_offset + utils.str.length(value),
            bot = indentation_count + icon_hl_range_offset + utils.str.length(value) + #icon_after.icon,
          },
        }
      end

      if items then
        local fold_symbol = symbols_setting:get(item.open and 'open' or 'close')
        local fold_header = string.format('%s%s %s', indentation, fold_symbol, value)
        local show_count = item.show_count

        if show_count ~= false then show_count = true end

        if show_count then
          local item_count = string.format('(%s)', #items)
          fold_header = string.format('%s %s', fold_header, item_count)
          hls[#hls + 1] = {
            hl = 'GitCount',
            lnum = current_lnum,
            range = {
              top = #fold_header - #item_count,
              bot = #fold_header,
            },
          }
        end

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
          hl = 'GitTitle',
          lnum = current_lnum,
          range = {
            top = 1 + indentation_count + #fold_symbol,
            bot = 1 + indentation_count + #fold_symbol + #value,
          },
        }

        if item.open then generate_lines(items, depth + 1) end
      else
        foldable_list_shadow[#foldable_list_shadow + 1] = string.format('%s%s', indentation, value)
      end
    end
  end

  table.sort(self.state.list, function(item1, item2)
    return item1.value > item2.value
  end)
  generate_lines(self.state.list, 0)

  self.state.hls = hls
  self.state.virtual_texts = virtual_texts

  return foldable_list_shadow
end

function FoldableListComponent:paint()
  local virtual_texts = self.state.virtual_texts
  for i = 1, #virtual_texts do
    local virtual_text = virtual_texts[i]
    -- TODO: add other support right now just use before
    if virtual_text.type == 'before' then
      self.buffer:transpose_virtual_text({
        text = virtual_text.text,
        hl = virtual_text.hl,
        row = virtual_text.lnum - 1,
        col = 0,
      })
    end
  end

  local hls = self.state.hls
  for i = 1, #hls do
    local hl_info = hls[i]
    local hl = hl_info.hl
    local lnum = hl_info.lnum
    local range = hl_info.range

    self.buffer:add_highlight({
      hl = hl,
      row = lnum - 1,
      col_range = {
        from = range.top,
        to = range.bot,
      },
    })
  end

  return self
end

function FoldableListComponent:sync()
  self.buffer:clear_namespace():set_lines(self:generate_lines())

  loop.free_textlock()
  self:paint()
  loop.free_textlock()

  return self
end

function FoldableListComponent:mount()
  if self.mounted then return self end

  local config = self.config

  self.buffer = Buffer():create():assign_options(config.buf_options)
  local buffer = self.buffer
  local plot = self.plot

  self.window = Window:open(buffer, plot.win_plot):assign_options(config.win_options)

  if config.elements.header then self.elements.header = HeaderElement():mount(plot.header_win_plot) end

  if config.elements.footer then self.elements.footer = FooterElement():mount(plot.footer_win_plot) end

  self.mounted = true

  return self
end

function FoldableListComponent:unmount()
  local header = self.elements.header
  local footer = self.elements.footer

  self.window:close()
  if header then header:unmount() end

  if footer then footer:unmount() end
end

return FoldableListComponent
