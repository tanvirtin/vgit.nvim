local M = {}

M.mark_up = function(wins, marks)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line_count = vim.api.nvim_buf_line_count(0)
    local new_lnum = nil
    for i = #marks, 1, -1 do
        local mark = marks[i]
        if mark.finish < lnum then
            new_lnum = mark.finish
            break
        elseif lnum > mark.start then
            new_lnum = mark.start
            break
        end
    end
    new_lnum = new_lnum and (new_lnum >= 1 or new_lnum <= line_count) and new_lnum or 1
    if new_lnum and lnum ~= new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
    else
        local finish_hunks_lnum = marks[#marks].finish
        finish_hunks_lnum = finish_hunks_lnum
                and (finish_hunks_lnum >= 1 or new_lnum <= line_count)
                and finish_hunks_lnum
            or 1
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { finish_hunks_lnum, 0 })
        end
        vim.cmd('norm! zz')
    end
end

M.mark_down = function(wins, marks)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line_count = vim.api.nvim_buf_line_count(0)
    local new_lnum = nil
    local selected_mark = nil
    for i = 1, #marks do
        local mark = marks[i]
        local compare_lnum = lnum
        if mark.type == 'remove' then
            compare_lnum = lnum + 1
        end
        if mark.start > compare_lnum then
            new_lnum = mark.start
            break
        elseif compare_lnum < mark.finish then
            new_lnum = mark.finish
            break
        end
    end
    new_lnum = new_lnum and (new_lnum >= 1 or new_lnum <= line_count) and new_lnum or 1
    local compare_lnum = lnum
    if selected_mark and selected_mark.type == 'remove' then
        compare_lnum = compare_lnum + 1
    end
    if new_lnum and compare_lnum ~= new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
    else
        local first_hunk_start_lnum = marks[1].start
        first_hunk_start_lnum = first_hunk_start_lnum
                and (first_hunk_start_lnum >= 1 or new_lnum <= line_count)
                and first_hunk_start_lnum
            or 1
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { first_hunk_start_lnum, 0 })
        end
        vim.cmd('norm! zz')
    end
end

M.hunk_up = function(wins, hunks)
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    for i = #hunks, 1, -1 do
        local hunk = hunks[i]
        if hunk.finish < lnum then
            new_lnum = hunk.finish
            break
        elseif lnum > hunk.start then
            new_lnum = hunk.start
            break
        end
    end
    if new_lnum and new_lnum < 1 then
        new_lnum = 1
    end
    if new_lnum and lnum ~= new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
    else
        local finish_hunks_lnum = hunks[#hunks].finish
        if finish_hunks_lnum < 1 then
            finish_hunks_lnum = 1
        end
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { finish_hunks_lnum, 0 })
        end
        vim.cmd('norm! zz')
    end
end

M.hunk_down = function(wins, hunks)
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    for i = 1, #hunks do
        local hunk = hunks[i]
        if hunk.start > lnum then
            new_lnum = hunk.start
            break
        elseif lnum < hunk.finish then
            new_lnum = hunk.finish
            break
        end
    end
    if new_lnum and new_lnum < 1 then
        new_lnum = 1
    end
    if new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
    else
        local first_hunk_start_lnum = hunks[1].start
        if first_hunk_start_lnum < 1 then
            first_hunk_start_lnum = 1
        end
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { first_hunk_start_lnum, 0 })
        end
        vim.cmd('norm! zz')
    end
end

M.set_cursor = function(...)
    return pcall(vim.api.nvim_win_set_cursor, ...)
end

return M
