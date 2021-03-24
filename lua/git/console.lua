local M = {}

M.log = function(...)
    str = ''
    for index, arg in ipairs{...} do
        if index == 1 then
            str = str .. arg
        else
            str = '\n' .. str .. arg
        end
    end
    vim.schedule(function()
        vim.cmd('echo "' .. str .. '"')
    end)
end

return M
