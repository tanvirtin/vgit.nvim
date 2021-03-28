local vim = vim

local M = {}

local function typecast(value)
    if type(value) == 'table' then
        return vim.inspect(value)
    end
    return value
end

M.info = vim.schedule_wrap(function(...)
    local str = ''
    for index, arg in ipairs{...} do
        if index == 1 then
            str = str .. typecast(arg)
        else
            str = str .. '\n' .. typecast(arg)
        end
    end
    vim.api.nvim_echo({{str}}, false, {})
end)

return M
