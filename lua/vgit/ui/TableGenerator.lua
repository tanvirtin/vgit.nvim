local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local TableGenerator = Object:extend()

function TableGenerator:constructor(labels, rows, spacing, max_len)
  return {
    labels = labels,
    rows = rows,
    spacing = spacing,
    max_len = max_len,
    paddings = nil,
  }
end

function TableGenerator:parse_item(item, row)
  local hl = {}
  local value = item.text

  if item.icon_before then
    value = string.format('%s %s', item.icon_before.icon, value)
    hl[#hl + 1] = {
      hl = item.icon_before.hl,
      row = row,
      range = {
        top = 1,
        bot = #item.icon_before.icon,
      },
    }
  end

  if item.icon_after then
    value = string.format('%s %s', value, item.icon_after.icon)
    hl[#hl + 1] = {
      hl = item.icon_after.hl,
      row = row,
      range = {
        top = utils.str.length(value) - 1,
        bot = utils.str.length(value) - 1 + #item.icon_after.icon,
      },
    }
  end

  return value, hl
end

function TableGenerator:generate_row(items, hls, r)
  local spacing = self.spacing
  local max_len = self.max_len
  local paddings = self.paddings

  local row = string.format('%s', string.rep(' ', spacing))

  for j = 1, #items do
    local item = items[j]
    local value, hl

    if type(item) == 'table' then
      value, hl = self:parse_item(item, r)
      value = utils.str.shorten(value, max_len)
    else
      value = utils.str.shorten(item, max_len)
    end

    if hl then
      for i = 1, #hl do
        local hl_range = hl[i].range
        hl_range.top = hl_range.top + utils.str.length(row)
        hl_range.bot = hl_range.bot + utils.str.length(row)
        hls[#hls + 1] = hl[i]
      end
    end

    row = string.format('%s%s%s', row, value, string.rep(' ', paddings[j] - utils.str.length(value)))
  end

  return row, hls
end

function TableGenerator:generate_rows()
  local rows = self.rows

  local lines = {}
  local hls = {}

  for i = 1, #rows do
    lines[#lines + 1] = self:generate_row(rows[i], hls, i)
  end

  for i = 1, #hls do
    local hl_info = hls[i]

    hl_info.range.top = hl_info.range.top + 1
    hl_info.range.bot = hl_info.range.bot + 1
  end

  return lines, hls
end

function TableGenerator:generate_labels()
  local labels = self.labels
  local spacing = self.spacing
  local max_len = self.max_len
  local paddings = self.paddings

  local row = string.format('%s', string.rep(' ', spacing))

  for j = 1, #labels do
    local item = labels[j]
    local value = utils.str.shorten(item, max_len)
    row = string.format('%s%s%s', row, value, string.rep(' ', paddings[j] - utils.str.length(value)))
  end

  return { row }
end

function TableGenerator:generate_paddings()
  local labels = self.labels
  local rows = self.rows
  local spacing = self.spacing
  local max_len = self.max_len

  local paddings = {}

  for i = 1, #rows do
    local items = rows[i]

    assert(#labels == #items, 'number of columns should be the same as number of column_labels')

    for j = 1, #items do
      local value = nil
      local item = items[j]

      if type(item) == 'table' then
        value, _ = self:parse_item(item, i)
        value = utils.str.shorten(value, max_len)
      else
        value = utils.str.shorten(item, max_len)
      end

      if paddings[j] then
        paddings[j] = math.max(paddings[j], utils.str.length(value) + spacing)
      else
        paddings[j] = spacing + utils.str.length(value) + spacing
      end
    end
  end

  self.paddings = paddings

  return self
end

function TableGenerator:generate()
  self:generate_paddings()

  local labels = self:generate_labels()
  local rows, hls = self:generate_rows()

  return labels, rows, hls
end

return TableGenerator
