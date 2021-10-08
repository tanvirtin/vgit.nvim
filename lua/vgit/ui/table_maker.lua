local utils = require('vgit.core.utils')

local table_maker = {}

table_maker.parse_item = function(item, row)
  local hl = {}
  local value = item.text
  if item.icon_before then
    value = string.format('%s %s', item.icon_before.icon, value)
    hl[#hl + 1] = {
      hl = item.icon_before.hl,
      row = row,
      range = {
        start = 1,
        finish = 1 + #item.icon_before.icon,
      },
    }
  end
  if item.icon_after then
    value = string.format('%s %s', value, item.icon_after.icon)
    hl[#hl + 1] = {
      hl = item.icon_after.hl,
      row = row,
      range = {
        start = #value - 1,
        finish = #value - 1 + #item.icon_after.icon,
      },
    }
  end
  return value, hl
end

table_maker.make_paddings =
  function(rows, column_labels, column_spacing, max_column_len)
    local padding = {}
    for i = 1, #rows do
      local items = rows[i]
      assert(
        #column_labels == #items,
        'number of columns should be the same as number of column_labels'
      )
      for j = 1, #items do
        local item = items[j]
        local value
        if type(item) == 'table' then
          value, _ = table_maker.parse_item(item, i)
          value = utils.shorten_string(value, max_column_len)
        else
          value = utils.shorten_string(item, max_column_len)
        end
        if padding[j] then
          padding[j] = math.max(padding[j], #value + column_spacing)
        else
          padding[j] = column_spacing + #value + column_spacing
        end
      end
    end
    return padding
  end

table_maker.make_row =
  function(items, paddings, column_spacing, max_column_len, hls, r)
    local row = string.format('%s', string.rep(' ', column_spacing))
    local icon_offset = 0
    for j = 1, #items do
      local item = items[j]
      local value, hl
      if type(item) == 'table' then
        icon_offset = 2
        value, hl = table_maker.parse_item(item, r)
        value = utils.shorten_string(value, max_column_len)
      else
        value = utils.shorten_string(item, max_column_len)
      end
      if hl then
        for i = 1, #hl do
          local hl_range = hl[i].range
          hl_range.start = hl_range.start + #row
          hl_range.finish = hl_range.finish + #row
          hls[#hls + 1] = hl[i]
        end
      end
      row = string.format(
        '%s%s%s',
        row,
        value,
        string.rep(' ', paddings[j] - #value + icon_offset)
      )
    end
    return row, hls
  end

table_maker.make_heading =
  function(column_labels, paddings, column_spacing, max_column_len)
    local row = string.format('%s', string.rep(' ', column_spacing))
    for j = 1, #column_labels do
      local item = column_labels[j]
      local value = utils.shorten_string(item, max_column_len)
      row = string.format(
        '%s%s%s',
        row,
        value,
        string.rep(' ', paddings[j] - #value)
      )
    end
    return { row }
  end

table_maker.make_rows = function(rows, paddings, column_spacing, max_column_len)
  local lines = {}
  local hls = {}
  for i = 1, #rows do
    -- Need to add a extra space in the front to account for the border in the header offset
    lines[#lines + 1] = ' '
      .. table_maker.make_row(
        rows[i],
        paddings,
        column_spacing,
        max_column_len,
        hls,
        i
      )
  end
  for i = 1, #hls do
    local hl_info = hls[i]
    hl_info.range.start = hl_info.range.start + 1
    hl_info.range.finish = hl_info.range.finish + 1
  end
  return lines, hls
end

return table_maker
