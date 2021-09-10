local Interface = require('vgit.Interface')

local M = {}

M.state = Interface:new({
    current = {},
})

M.get = function()
    return M.state:get('current')
end

M.set = function(popup)
    assert(type(popup) == 'table', 'type error :: expected table')
    M.state:set('current', popup)
end

M.exists = function()
    return not vim.tbl_isempty(M.get())
end

M.clear = function()
    if M.exists() then
        M.get():unmount()
        M.state:set('current', {})
    end
end

return M
