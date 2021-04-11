local git = require('git.git')
local ui = require('git.ui')
local defer = require('git.defer')

local vim = vim

local function get_initial_state()
    return {
        current_buf = nil,
        current_filepath = nil,
        current_buf_hunks = {}
    }
end

local state = get_initial_state()

local M = {
    buf_attach = vim.schedule_wrap(defer.throttle_leading(function(current_buf)
        if not current_buf then
            current_buf = vim.api.nvim_get_current_buf()
        end
        local filepath = vim.api.nvim_buf_get_name(current_buf)
        if not filepath or filepath == '' then
            return
        end
        git.buffer_hunks(filepath, function(err, hunks)
            if not err then
                state.current_buf = current_buf
                state.current_filepath = filepath
                state.current_buf_hunks = hunks

                ui.hide_hunk_signs()
                ui.show_hunk_signs(filepath, hunks)
            end
        end)
    end, 100)),

    hunk_preview = vim.schedule_wrap(function()
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(state.current_buf_hunks) do
            -- NOTE: When hunk is of type remove in ui.lua, we set the lnum to be 1 instead of 0.
            if lnum == 1 and hunk.start == 0 and hunk.finish == 0 then
                return ui.show_hunk(hunk)
            end
            if lnum >= hunk.start and lnum <= hunk.finish then
                return ui.show_hunk(hunk)
            end
        end
    end),

    hunk_down = vim.schedule_wrap(function()
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(state.current_buf_hunks) do
            if hunk.start > lnum then
                new_lnum = hunk.start
                break
                -- If you are within the same hunk then I go to the bottom of the hunk.
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
        local new_lnum = nil
        local lnum = vim.api.nvim_win_get_cursor(0)[1]
        for i = #state.current_buf_hunks, 1, -1 do
            local hunk = state.current_buf_hunks[i]
            if hunk.finish < lnum then
                new_lnum = hunk.finish
                break
                -- If you are within the same hunk then I go to the top of the hunk.
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
        local current_buf = state.current_buf
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
                local is_line_removed = vim.startswith(line, '-')
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
                else
                    -- Insertion happens after the given index which is why we do start - 1
                    vim.api.nvim_buf_set_lines(current_buf, start - 1, finish, false, replaced_lines)
                end
                vim.api.nvim_win_set_cursor(0, { start, 0 })
                vim.api.nvim_command('update')
            end
        end
    end),

    diff_preview = vim.schedule_wrap(function()
        local filepath = state.current_filepath
        local bufnr = state.current_buf
        local hunks = state.current_buf_hunks
        if not filepath or filepath == '' or not bufnr or not hunks or type(hunks) ~= 'table' or #hunks == 0 then
            return
        end
        git.diff(filepath, hunks, function(err, cwd_content, origin_content, lnum_changes, file_type)
            if not err then
                -- NOTE: This prevents hunk navigation, hunk preview, etc disabled on the split window.
                -- when split window is closed buf_attach is triggered on the current buffer you will be on.
                state = {
                    current_buf = nil,
                    current_filepath = nil,
                    current_buf_hunks = {}
                }
                local bufs = vim.api.nvim_list_bufs()
                local cwd_buf, cwd_win_id, _, origin_win_id = ui.show_diff(cwd_content, origin_content, lnum_changes, file_type)
                -- Close on cmd/ctrl - c.
                vim.api.nvim_buf_set_keymap(
                    cwd_buf,
                    'n',
                    '<C-c>',
                    string.format(':lua require("git").close_preview_window(%s, %s)<CR>', cwd_win_id, origin_win_id),
                    { silent = true }
                )
                -- Close on esc.
                vim.api.nvim_buf_set_keymap(
                    cwd_buf,
                    'n',
                    '<ESC>',
                    string.format(':lua require("git").close_preview_window(%s, %s)<CR>', cwd_win_id, origin_win_id),
                    { silent = true }
                )
                for _, buf in ipairs(bufs) do
                    -- Once split windows are shown, anytime when any other buf currently available enters any window the splits close.
                    vim.api.nvim_command(
                        string.format(
                            'autocmd BufEnter <buffer=%s> lua require("git").close_preview_window(%s, %s)',
                            buf,
                            cwd_win_id,
                            origin_win_id
                        )
                    )
                end
            end
        end)
    end),

    -- Wrapper around nvim_win_close, indented for a better autocmd experience.
    close_preview_window = function(...)
        local args = {...}
        for _, win_id in ipairs(args) do
            if vim.api.nvim_win_is_valid(win_id) then
                vim.api.nvim_win_close(win_id, false)
            end
        end
    end,

    buf_detach = function()
        git.tear_down()
        ui.tear_down()
        state = get_initial_state()
    end,

    setup = function()
        git.initialize()
        ui.initialize()
        vim.api.nvim_command('autocmd BufEnter,BufWritePost * lua require("git").buf_attach()')
        vim.api.nvim_command('autocmd BufLeave,VimLeavePre * lua require("git").buf_detach()')
    end
}

return M
