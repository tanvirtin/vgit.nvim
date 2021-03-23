local git = require('git.git')
local sign = require('git.sign')
local window = require('git.window')

local memory = {
    current_buf = nil,
    current_buf_hunks = {}
}

return {
    attach = vim.schedule_wrap(function()
        if not memory then
            return
        end
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
    end),

    hunk_preview = vim.schedule_wrap(function()
        if not memory then
            return
        end
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(memory.current_buf_hunks) do
            if lnum >= hunk.start and lnum <= hunk.finish then
                window.popup(hunk.diff, { relative = 'cursor' })
                break
            end
        end
    end),

    hunk_down = vim.schedule_wrap(function()
        if not memory or #memory.current_buf_hunks < 1 then
            return
        end
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(memory.current_buf_hunks) do
            if hunk.start > lnum then
                new_lnum = hunk.start
                break
            elseif lnum < hunk.finish then
                new_lnum = hunk.finish
                break
            end
        end
        if new_lnum then
            vim.api.nvim_win_set_cursor(0, { new_lnum, 0 })
        end
    end),

    hunk_up = vim.schedule_wrap(function()
        if not memory or #memory.current_buf_hunks < 1 then
            return
        end
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for i = #memory.current_buf_hunks, 1, -1 do
            local hunk = memory.current_buf_hunks[i]
            if hunk.finish < lnum then
                new_lnum = hunk.finish
                break
            elseif lnum > hunk.start then
                new_lnum = hunk.start
                break
            end
        end
        if new_lnum then
            vim.api.nvim_win_set_cursor(0, { new_lnum, 0 })
        end
    end),

    hunk_reset = vim.schedule_wrap(function()
        if not memory then
            return
        end
        local current_buf = memory.current_buf
        local added_lines = {}
        local removed_lines = {}
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local selected_hunk = nil
        for _, hunk in ipairs(memory.current_buf_hunks) do
            if lnum >= hunk.start and lnum <= hunk.finish then
                selected_hunk = hunk
                break
            end
        end
        if selected_hunk then
            local replaced_lines = {}
            for _, line in ipairs(selected_hunk.diff) do
                is_line_removed = vim.startswith(line, '-')
                if is_line_removed then
                    table.insert(replaced_lines, string.sub(line, 2, -1))
                end
            end
            local start = selected_hunk.start
            local finish = selected_hunk.finish
            if start and finish then
                if selected_hunk.type == 'delete' then
                    finish = finish + 1
                end
                vim.api.nvim_buf_set_lines(current_buf, start - 1, finish, false, replaced_lines)
                vim.api.nvim_win_set_cursor(0, { start - 1, 0 })
                vim.cmd('w')
            end
        end
    end),

    detach = function()
        memory = nil
    end,

    setup = function(config)
        sign.initialize(config)
        vim.cmd('autocmd BufEnter,BufWritePost * lua require("git").attach()')
        vim.cmd('autocmd VimLeavePre * lua require("git").detach()')
    end
}
