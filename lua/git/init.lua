local git = require('git.git')
local sign = require('git.sign')
local flow_control = require('git.flow_control')
local window = require('git.window')

local memory = {
    current_buf = nil,
    current_buf_hunks = {}
}

return {
    attach = flow_control.throttle(100, flow_control.async(function()
        local current_buf = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(buf)
        git.diff(filepath, function(err, hunks)
            if not err then
                sign.clear_all()
                for _, hunk in ipairs(hunks) do
                    table.insert(memory, hunk)
                    sign.place(hunk)
                end
                memory.current_buf = current_buf
                memory.current_buf_hunks = hunks
            end
        end)
    end)()),

    preview_hunk = flow_control.async(function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        lnum = tonumber(lnum)
        for _, hunk in ipairs(memory.current_buf_hunks) do
            if lnum >= hunk.start and lnum <= hunk.finish then
                window.popup(hunk.diff, {
                    relative = 'cursor'
                })
                break
            end
        end
    end)(),

    detach = function()
        memory = nil
    end,

    setup = function(config)
        sign.initialize(config)
        vim.cmd('autocmd BufEnter,BufWritePost * lua vim.schedule(require("git").attach)')
        vim.cmd('autocmd VimLeavePre * lua require("git").detach()')
    end
}
