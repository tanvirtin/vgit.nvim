local M = {}

M.add = function(group, color)
    local style = color.style and "gui=" .. color.style or "gui=NONE"
    local fg = color.fg and "guifg = " .. color.fg or "guifg = NONE"
    local bg = color.bg and "guibg = " .. color.bg or "guibg = NONE"
    local sp = color.sp and "guisp = " .. color.sp or ""
    vim.api.nvim_command("highlight " .. group .. " " .. style .. " " .. fg .. " " .. bg .. " " .. sp)
end

return M
