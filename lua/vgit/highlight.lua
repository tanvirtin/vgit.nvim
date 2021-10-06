local Interface = require('vgit.Interface')

local M = {}

M.state = Interface:new(require('vgit.themes.monokai'))

M.exists = function(name)
  return pcall(vim.api.nvim_get_hl_by_name, name, true)
end

M.create = function(group, color)
  local gui = color.gui and 'gui = ' .. color.gui or 'gui = NONE'
  local fg = color.fg and 'guifg = ' .. color.fg or 'guifg = NONE'
  local bg = color.bg and 'guibg = ' .. color.bg or 'guibg = NONE'
  local sp = color.sp and 'guisp = ' .. color.sp or ''
  vim.cmd(
    'highlight ' .. group .. ' ' .. gui .. ' ' .. fg .. ' ' .. bg .. ' ' .. sp
  )
end

M.create_theme = function(hls)
  for hl, color in pairs(hls) do
    M.create(hl, color)
  end
end

M.setup = function(config, force)
  M.state:assign((config and config.hls) or config)
  for hl, color in pairs(M.state.data) do
    if force or not M.exists(hl) then
      M.create(hl, color)
    end
  end
end

return M
