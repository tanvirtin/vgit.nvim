local git = require('git.git')
local sign = require('git.sign')
local previewer = require('git.previewer')

local state = {
    current_buf = nil,
    current_buf_hunks = {}
}

return {
    initialize = vim.schedule_wrap(function()
        if not state then
            return
        end
        local current_buf = vim.api.nvim_get_current_buf()
        if not current_buf then
            return
        end
        local filepath = vim.api.nvim_buf_get_name(buf)
        if not filepath or filepath == '' then
            return
        end
        git.diff(filepath, function(err, hunks)
            if not err then
                sign.clear_all()
                for _, hunk in ipairs(hunks) do
                    table.insert(state, hunk)
                    sign.place(hunk)
                end
                state.current_buf = current_buf
                state.current_buf_hunks = hunks
            end
        end)
    end),

    hunk_preview = vim.schedule_wrap(function()
        if not state then
            return
        end
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(state.current_buf_hunks) do
            if lnum >= hunk.start and lnum <= hunk.finish then
                previewer.show_hunk(hunk)
                break
            end
        end
    end),

    hunk_down = vim.schedule_wrap(function()
        if not state or #state.current_buf_hunks < 1 then
            return
        end
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(state.current_buf_hunks) do
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
        if not state or #state.current_buf_hunks < 1 then
            return
        end
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for i = #state.current_buf_hunks, 1, -1 do
            local hunk = state.current_buf_hunks[i]
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
        if not state then
            return
        end
        local current_buf = state.current_buf
        local added_lines = {}
        local removed_lines = {}
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        local selected_hunk = nil
        for _, hunk in ipairs(state.current_buf_hunks) do
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
                if selected_hunk.type == 'remove' then
                    -- Api says start == finish (which is the case here) all the lines are inserted from that point.
                    vim.api.nvim_buf_set_lines(current_buf, start, finish, false, replaced_lines)
                    vim.api.nvim_win_set_cursor(0, { start + 1, 0 })
                else
                    -- Insertion happens after the given index which is why we do start - 1
                    vim.api.nvim_buf_set_lines(current_buf, start - 1, finish, false, replaced_lines)
                    vim.api.nvim_win_set_cursor(0, { start - 1, 0 })
                end
                vim.cmd('w')
            end
        end
    end),

    tear_down = function()
        git.tear_down()
        sign.tear_down()
        previewer.tear_down()
        state = nil
    end,

    setup = function(config)
        git.initialize()
        previewer.initialize()
        sign.initialize()
        vim.cmd('autocmd BufEnter,BufWritePost * lua require("git").initialize()')
        vim.cmd('autocmd VimLeavePre * lua require("git").tear_down()')
    end
}
