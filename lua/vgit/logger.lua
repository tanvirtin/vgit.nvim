local Interface = require('vgit.Interface')

local vim = vim

local M = {}

M.state = Interface.new({
    debug = false,
    debug_logs = {},
})

M.setup = function(config)
    M.state:assign(config)
end

M.error = function(msg)
    vim.api.nvim_command('echohl ErrorMsg')
    vim.api.nvim_command(string.format('echom "VGit[%s]: %s"', os.date('%H:%M:%S'), vim.fn.escape(msg, '"')))
    vim.api.nvim_command('echohl NONE')
end

M.info = function(msg)
    vim.api.nvim_command(string.format('echom "%s"', vim.fn.escape(msg, '"')))
end

M.debug = function(msg, fn)
    fn = fn or 'unknown'
    if M.state:get('debug') then
        local new_msg = ''
        if vim.tbl_islist(msg) then
            for i = 1, #msg do
                local m = msg[i]
                if i == 1 then
                    new_msg = new_msg .. m
                else
                    new_msg = new_msg .. ', ' .. m
                end
            end
        else
            new_msg = msg
        end
        local debug_logs = M.state:get('debug_logs')
        debug_logs[#debug_logs + 1] = string.format('VGit[%s][%s]: %s', os.date('%H:%M:%S'), fn, new_msg)
    end
end

return M
