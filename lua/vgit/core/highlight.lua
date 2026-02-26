local lazy = require('vgit.core.lazy')

local event = lazy('vgit.core.event')
local hls_setting = lazy('vgit.settings.hls')

local highlight = {}

function highlight.define(group, color, force)
  if type(color) == 'string' then
    vim.api.nvim_exec(string.format('highlight default link %s %s', group, color), false)

    return highlight
  end

  if type(color) == 'function' then color = color() end

  local gui = color.gui and 'gui = ' .. color.gui or 'gui = NONE'
  local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
  local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
  local sp = color.sp and 'guisp = ' .. color.sp or ''

  local default = (not force and color.override == false) and 'default ' or ''
  vim.api.nvim_exec('highlight ' .. default .. group .. ' ' .. gui .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp, false)

  return highlight
end

function highlight.register_module(dependency)
  hls_setting:for_each(function(hl, color)
    highlight.define(hl, color)
  end)

  if dependency then dependency() end

  return highlight
end

function highlight.register_events()
  event.on('ColorScheme', function()
    hls_setting:for_each(function(hl, color)
      highlight.define(hl, color)
    end)
  end)
end

return highlight
