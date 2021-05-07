local git = require('git.git')
local ui = require('git.ui')
local defer = require('git.defer')

local vim = vim

local function get_initial_state()
    return {
        config = {},
        hunks = {},
        blames = {},
        hunks_enabled = true,
        blames_enabled = true,
        blame_is_shown = false,
    }
end

local state = get_initial_state()

local M = {}

M.buf_attach = defer.throttle_leading(vim.schedule_wrap(function(buf)
    if not buf then
        buf = vim.api.nvim_get_current_buf()
    end
    state.hunks = {}
    state.blames = {}
    local filename = vim.api.nvim_buf_get_name(buf)
    if not filename or filename == '' then
        return
    end
    if state.hunks_enabled then
        local hunks_err, hunks = git.buffer_hunks(filename)
        if not hunks_err then
            state.hunks = hunks
            ui.show_hunk_signs(buf, hunks)
        end
    end
    if state.blames_enabled then
        local blames_err, blames = git.buffer_blames(filename)
        if not blames_err then
            state.blames = blames
        end
    end
end), 50)

M.hunk_preview = vim.schedule_wrap(function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local selected_hunk = nil
    for _, hunk in ipairs(state.hunks) do
        -- NOTE: When hunk is of type remove in ui.lua, we set the lnum to be 1 instead of 0.
        if lnum == 1 and hunk.start == 0 and hunk.finish == 0 then
            selected_hunk = hunk
            break
        end
        if lnum >= hunk.start and lnum <= hunk.finish then
            selected_hunk = hunk
            break
        end
    end
    if selected_hunk then
        state.hunks = {}
        state.blames = {}
        ui.show_hunk(selected_hunk, vim.api.nvim_buf_get_option(0, 'filetype'))
    end
end)

M.hunk_down = function()
    if #state.hunks == 0 then
        return
    end
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    for _, hunk in ipairs(state.hunks) do
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
        vim.api.nvim_command('norm! zz')
    else
        vim.api.nvim_win_set_cursor(0, { state.hunks[1].start, 0 })
        vim.api.nvim_command('norm! zz')
    end
end

M.hunk_up = function()
    if #state.hunks == 0 then
        return
    end
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    for i = #state.hunks, 1, -1 do
        local hunk = state.hunks[i]
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
        vim.api.nvim_command('norm! zz')
    else
        vim.api.nvim_win_set_cursor(0, { state.hunks[#state.hunks].start, 0 })
        vim.api.nvim_command('norm! zz')
    end
end

M.hunk_reset = function()
    local lnum = vim.api.nvim_win_get_cursor(0)[1]
    local selected_hunk = nil
    local selected_hunk_index = nil
    for index, hunk in ipairs(state.hunks) do
        if lnum >= hunk.start and lnum <= hunk.finish then
            selected_hunk = hunk
            selected_hunk_index = index
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
                vim.api.nvim_buf_set_lines(0, start, finish, false, replaced_lines)
            else
                -- Insertion happens after the given index which is why we do start - 1
                vim.api.nvim_buf_set_lines(0, start - 1, finish, false, replaced_lines)
            end
            vim.api.nvim_win_set_cursor(0, { start, 0 })
            vim.api.nvim_command('update')
            table.remove(state.hunks, selected_hunk_index)
            ui.hide_hunk_signs()
            ui.show_hunk_signs(vim.api.nvim_get_current_buf(), state.hunks)
        end
    end
end

M.toggle_buffer_hunks = vim.schedule_wrap(function()
    local filename = vim.api.nvim_buf_get_name(0)
    if not filename or filename == '' then
        return
    end
    if state.hunks_enabled then
        state.hunks_enabled = false
        state.hunks = {}
        ui.hide_hunk_signs()
        return
    end
    local hunks_err, hunks = git.buffer_hunks(filename)
    if not hunks_err then
        state.hunks_enabled = true
        state.hunks = hunks
        local buf = vim.api.nvim_get_current_buf()
        ui.show_hunk_signs(buf, hunks)
    end
end)

M.toggle_buffer_blames = vim.schedule_wrap(function()
    local filename = vim.api.nvim_buf_get_name(0)
    if not filename or filename == '' then
        return
    end
    vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
    if state.blames_enabled then
        state.blames_enabled = false
        state.blames = {}
        M.unblame_line()
        return
    end
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("git").blame_line()')
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("git").unblame_line()')
    local err, blames = git.buffer_blames(filename)
    if not err then
        state.blames_enabled = true
        state.blames = blames
    end
end)

M.blame_line = vim.schedule_wrap(function(buf)
    if #state.blames == 0 then
        return
    end
    if not buf then
        buf = vim.api.nvim_get_current_buf()
    end
    ui.show_blame(buf, state.blames, git.state().config)
    state.blame_is_shown = true
end)

M.unblame_line = defer.throttle_leading(function(buf)
    if not state.blame_is_shown then
        return
    end
    if not buf then
        buf = vim.api.nvim_get_current_buf()
    end
    ui.hide_blame(buf)
    state.blame_is_shown = false
end, vim.o.updatetime)

M.buffer_preview = vim.schedule_wrap(function()
    local buf = vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)
    if not filename or filename == '' then
        return
    end
    local hunks = state.hunks
    if not state.hunks_enabled then
        local err, computed_hunks = git.buffer_hunks(filename)
        if not err then
            hunks = computed_hunks
        end
    end
    if #hunks == 0 then
        return
    end
    local filetype = vim.api.nvim_buf_get_option(0, 'filetype')
    local err, data = git.buffer_diff(vim.api.nvim_buf_get_name(0), hunks)
    if err then
        return
    end
    state.hunks = {}
    state.blames = {}
    ui.show_diff(
        data.cwd_lines,
        data.origin_lines,
        data.lnum_changes,
        filetype
    )
end)

M.buffer_reset = function()
    if #state.hunks == 0 then
        return
    end
    local err = git.buffer_reset(vim.api.nvim_buf_get_name(0))
    if not err then
        vim.api.nvim_command('e!')
        state.hunks = {}
        ui.hide_hunk_signs()
    end
end

-- Wrapper around nvim_win_close, indented for a better autocmd experience.
M.close_preview_window = function(...)
    local args = {...}
    for _, win_id in ipairs(args) do
        if vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, false)
        end
    end
end

M.buf_detach = function()
    git.tear_down()
    ui.tear_down()
    state = get_initial_state()
end

M.setup = function()
    git.initialize()
    ui.initialize()
    vim.api.nvim_command('augroup tanvirtin/vgit | autocmd! | augroup END')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufEnter,BufWritePost * lua require("git").buf_attach()')
    vim.api.nvim_command('autocmd tanvirtin/vgit VimLeavePre * lua require("git").buf_detach()')

    if state.blames_enabled then
        vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("git").blame_line()')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("git").unblame_line()')
    end
end

return M
