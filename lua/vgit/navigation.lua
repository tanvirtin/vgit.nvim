local wrap = require('plenary.async.async').wrap

local M = {}

M.mark_up = wrap(function(wins, marks)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line_count = vim.api.nvim_buf_line_count(0)
    local new_lnum = nil
    local mark_index = 0
    for i = #marks, 1, -1 do
        local mark = marks[i]
        if mark.finish < lnum then
            new_lnum = mark.finish
            mark_index = i
            break
        elseif lnum > mark.start then
            new_lnum = mark.start
            mark_index = i
            break
        end
    end
    if not new_lnum or new_lnum < 1 or new_lnum > line_count then
        if marks and marks[#marks] and marks[#marks].finish then
            new_lnum = marks[#marks].finish
            mark_index = #marks
        else
            new_lnum = 1
            mark_index = 1
        end
    end
    if new_lnum and lnum ~= new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
        return mark_index
    else
        local finish_hunks_lnum = marks[#marks].finish
        finish_hunks_lnum = finish_hunks_lnum
                and (finish_hunks_lnum >= 1 or new_lnum <= line_count)
                and finish_hunks_lnum
            or 1
        mark_index = finish_hunks_lnum and (finish_hunks_lnum >= 1 or new_lnum <= line_count) and #marks or 1
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { finish_hunks_lnum, 0 })
        end
        vim.cmd('norm! zz')
        return mark_index
    end
end, 2)

M.mark_down = wrap(function(wins, marks)
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local line_count = vim.api.nvim_buf_line_count(0)
    local new_lnum = nil
    local selected_mark = nil
    local mark_index = 0
    for i = 1, #marks do
        local mark = marks[i]
        local compare_lnum = lnum
        if mark.type == 'remove' then
            compare_lnum = lnum + 1
        end
        if mark.start > compare_lnum then
            new_lnum = mark.start
            mark_index = i
            break
        elseif compare_lnum < mark.finish then
            new_lnum = mark.finish
            mark_index = i
            break
        end
    end
    if not new_lnum or new_lnum < 1 or new_lnum > line_count then
        if marks and marks[1] and marks[1].start then
            new_lnum = marks[1].start
            mark_index = 1
        else
            new_lnum = 1
            mark_index = 1
        end
    end
    local compare_lnum = lnum
    if selected_mark and selected_mark.type == 'remove' then
        compare_lnum = compare_lnum + 1
    end
    if new_lnum and compare_lnum ~= new_lnum then
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { new_lnum, 0 })
        end
        vim.cmd('norm! zz')
        return mark_index
    else
        local first_hunk_start_lnum = marks[1].start
        first_hunk_start_lnum = first_hunk_start_lnum
                and (first_hunk_start_lnum >= 1 and new_lnum <= line_count)
                and first_hunk_start_lnum
            or 1
        mark_index = first_hunk_start_lnum and (first_hunk_start_lnum >= 1 or new_lnum <= line_count) and 1 or 1
        for i = 1, #wins do
            vim.api.nvim_win_set_cursor(wins[i], { first_hunk_start_lnum, 0 })
        end
        vim.cmd('norm! zz')
        return mark_index
    end
end, 2)

M.hunk_up = wrap(function(wins, hunks)
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
end, 2)

M.hunk_down = wrap(function(wins, hunks)
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
end, 2)

M.set_cursor = function(...)
    return pcall(vim.api.nvim_win_set_cursor, ...)
end

return M
