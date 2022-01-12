local hls_setting = require('vgit.settings.hls')

local highlight = {}

highlight.define = function(group, color)
  local link = color
  if color.override == false then
    local ok, hl = pcall(vim.api.nvim_get_hl_by_name, group, true)
    -- TODO: If a highlight gets cleared neovim returns { [true] = 'some id' }.
    --       this might be changed in the future by neovim, revisit this.
    if ok and (type(hl) == 'table' and not hl[true] and hl ~= nil) then
      return
    end
  end
  if type(link) == 'string' then
    vim.api.nvim_exec(string.format('highlight link %s %s', group, link), false)
    return
  end
  local gui = color.gui and 'gui = ' .. color.gui or 'gui = NONE'
  local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
  local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
  local sp = color.sp and 'guisp = ' .. color.sp or ''
  vim.api.nvim_exec(
    'highlight ' .. group .. ' ' .. gui .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp,
    false
  )
end

highlight.register_module = function(dependency)
  hls_setting:for_each(function(hl, color)
    highlight.define(hl, color)
  end)
  if dependency then
    dependency()
  end
end

return highlight
