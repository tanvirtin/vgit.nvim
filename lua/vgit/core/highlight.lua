local hls_setting = require('vgit.settings.hls')

local highlight = {}

function highlight.define(group, color, force)
  if type(color) == 'string' then
    vim.api.nvim_exec(
      string.format('highlight link %s %s', group, color),
      false
    )

    return highlight
  end

  if type(color) == 'function' then
    color = color()
  end

  if not force and color.override == false then
    local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group, true)
    if ok and (type(hl) == 'table' and not hl[true] and hl ~= nil) then
      return
    end
  end

  local gui = color.gui and 'gui = ' .. color.gui or 'gui = NONE'
  local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
  local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
  local sp = color.sp and 'guisp = ' .. color.sp or ''

  vim.api.nvim_exec(
    'highlight ' .. group .. ' ' .. gui .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp,
    false
  )

  return highlight
end

function highlight.register_module(dependency)
  hls_setting:for_each(function(hl, color)
    highlight.define(hl, color)
  end)

  if dependency then
    dependency()
  end

  return highlight
end

return highlight
