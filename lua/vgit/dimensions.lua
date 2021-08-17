local M = {}

M.global_width = function()
    return vim.o.columns
end

M.global_height = function()
    return vim.o.lines
end

return M
