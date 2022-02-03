local fs = require('vgit.core.fs')
local icons = require('vgit.core.icons')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local HeaderTitle = Object:extend()

function HeaderTitle:new()
  return setmetatable({}, HeaderTitle)
end

function HeaderTitle:set(source, title, opts)
  opts = opts or {}
  local filename = opts.filename
  local filetype = opts.filetype
  local stat = opts.stat
  local text = title
  if filename or filetype or stat then
    text = utils.str.concat(title, ': ')
  end
  local hl_range_infos = {}
  if filename then
    text = utils.str.concat(text, fs.short_filename(filename))
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
  source:set_lines({ text })
  for _, range_info in ipairs(hl_range_infos) do
    local hl = range_info.hl
    local range = range_info.range
    source:add_highlight(hl, 0, range.top, range.bot)
  end
  return self
end

return HeaderTitle
