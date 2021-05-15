local git = require('vgit.git')
local ui = require('vgit.ui')
local defer = require('vgit.defer')
local configurer = require('vgit.configurer')

local vim = vim

local function get_initial_state()
    return {
        bufs = {},
        config = {},
        hunks_enabled = true,
        blames_enabled = true,
    }
end

local function log_error(msg)
    vim.cmd('echohl ErrorMsg')
    vim.cmd(string.format('echo "%s"', msg))
    vim.cmd('echohl None')
end

local state = get_initial_state()

local M = {}

local function create_buf_state(buf)
    local buf_state = {
        hunks = {},
        blames = {},
        blame_is_shown = false,
        last_lnum = 1
    }
    state.bufs[tostring(buf)] = buf_state
    return buf_state
end

local function get_buf_state(buf)
    return state.bufs[tostring(buf)]
end

local function clear_buf_state(buf)
    local buf_state = state.bufs[tostring(buf)]
    state.bufs[tostring(buf)] = nil
    return buf_state
end

M._buf_attach = defer.throttle_leading(vim.schedule_wrap(function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local buf_state = create_buf_state(buf)
    local filename = vim.api.nvim_buf_get_name(buf)
    if not filename or filename == '' then
        return
    end
    if state.hunks_enabled then
        local hunks_err, hunks = git.buffer_hunks(filename)
        if not hunks_err then
            buf_state.hunks = hunks
            ui.hide_hunk_signs(buf)
            ui.show_hunk_signs(buf, hunks)
        end
    end
    if state.blames_enabled then
        local blames_err, blames = git.buffer_blames(filename)
        if not blames_err then
            buf_state.blames = blames
        end
    end
end), 50)

M._buf_detach = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    clear_buf_state(buf)
end

M._close_preview_window = function(...)
    local args = {...}
    for _, win in ipairs(args) do
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end
end

M._tear_down = function()
    git.tear_down()
    ui.tear_down()
    state = get_initial_state()
end

M._blame_line = vim.schedule_wrap(function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    if #buf_state.blames == 0 then
        return
    end
    local is_buf_modified = vim.api.nvim_buf_get_option(buf, 'modified')
    if is_buf_modified  then
        return
    end
    local win = vim.api.nvim_get_current_win()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    buf_state.last_lnum = lnum
    ui.show_blame(buf, buf_state.blames, git.get_state().config)
    buf_state.blame_is_shown = true
end)

M._unblame_line = function(buf, override)
    buf = buf or vim.api.nvim_get_current_buf()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    if not buf_state.blame_is_shown then
        return
    end
    local win = vim.api.nvim_get_current_win()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    if override then
        ui.hide_blame(buf)
        buf_state.blame_is_shown = false
        return
    end
    if buf_state.last_lnum ~= lnum then
        ui.hide_blame(buf)
        buf_state.blame_is_shown = false
    end
end

M._run_command = function(command, ...)
    local starts_with = command:sub(1, 1)
    if starts_with == '_' or not M[command] then
        log_error('Invalid argument for VGit')
        return
    end
    M[command](...)
end

M.hunk_preview = vim.schedule_wrap(function(buf, win)
    buf = buf or vim.api.nvim_get_current_buf()
    win = win or vim.api.nvim_get_current_win()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local selected_hunk = nil
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    for _, hunk in ipairs(hunks) do
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
        ui.show_hunk(selected_hunk, vim.api.nvim_buf_get_option(0, 'filetype'))
    end
end)

M.hunk_down = function(buf, win)
    buf = buf or vim.api.nvim_get_current_buf()
    win = win or vim.api.nvim_get_current_win()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    if #hunks == 0 then
        return
    end
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    for _, hunk in ipairs(hunks) do
        if hunk.start > lnum then
            new_lnum = hunk.start
            break
        elseif lnum < hunk.finish then
            new_lnum = hunk.finish
            break
        end
    end
    if new_lnum then
        vim.api.nvim_win_set_cursor(win, { new_lnum, 0 })
        vim.api.nvim_command('norm! zz')
    else
        vim.api.nvim_win_set_cursor(win, { hunks[1].start, 0 })
        vim.api.nvim_command('norm! zz')
    end
end

M.hunk_up = function(buf, win)
    buf = buf or vim.api.nvim_get_current_buf()
    win = win or vim.api.nvim_get_current_win()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    if #hunks == 0 then
        return
    end
    local new_lnum = nil
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
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
    if new_lnum and lnum ~= new_lnum then
        vim.api.nvim_win_set_cursor(win, { new_lnum, 0 })
        vim.api.nvim_command('norm! zz')
    else
        vim.api.nvim_win_set_cursor(win, { hunks[#hunks].finish, 0 })
        vim.api.nvim_command('norm! zz')
    end
end

M.hunk_reset = function(buf, win)
    buf = buf or vim.api.nvim_get_current_buf()
    win = win or vim.api.nvim_get_current_win()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local selected_hunk = nil
    local selected_hunk_index = nil
    for index, hunk in ipairs(hunks) do
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
                vim.api.nvim_buf_set_lines(0, start, finish, false, replaced_lines)
            else
                vim.api.nvim_buf_set_lines(0, start - 1, finish, false, replaced_lines)
            end
            vim.api.nvim_win_set_cursor(win, { start, 0 })
            vim.api.nvim_command('update')
            table.remove(hunks, selected_hunk_index)
            ui.hide_hunk_signs(buf)
            ui.show_hunk_signs(buf, hunks)
        end
    end
end

M.hunks_quickfix = function()
    local err, filenames = git.ls()
    if not err then
        local qf_entries = {}
        for _, filename in ipairs(filenames) do
            local hunks_err, hunks = git.buffer_hunks(filename)
            if not hunks_err then
                for _, hunk in ipairs(hunks) do
                    table.insert(qf_entries, {
                        text = hunk.header,
                        filename = filename,
                        lnum = hunk.start,
                        col = 0,
                    })
                end
            end
        end
        vim.fn.setqflist(qf_entries, 'r')
        vim.api.nvim_command('copen')
    end
end

M.toggle_buffer_hunks = vim.schedule_wrap(function()
    if state.hunks_enabled then
        state.hunks_enabled = false
        local bufs = state.bufs
        for buf, _ in pairs(bufs) do
            local buf_state = get_buf_state(buf)
            if buf_state then
                buf_state.hunks = {}
                ui.hide_hunk_signs(buf)
                return
            end
        end
        return
    end
    local bufs = state.bufs
    for buf, _ in pairs(bufs) do
        local bufnr = tonumber(buf)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        if filename and filename ~= '' then
            local hunks_err, hunks = git.buffer_hunks(filename)
            if not hunks_err then
                state.hunks_enabled = true
                local buf_state = get_buf_state(buf)
                if buf_state then
                    buf_state.hunks = hunks
                    ui.show_hunk_signs(bufnr, hunks)
                    return
                end
            end
        end
    end
end)

M.toggle_buffer_blames = vim.schedule_wrap(function()
    vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
    if state.blames_enabled then
        state.blames_enabled = false
        local bufs = state.bufs
        for buf, _ in pairs(bufs) do
            local buf_state = get_buf_state(buf)
            if buf_state then
                local bufnr = tonumber(buf)
                M._unblame_line(bufnr, true)
                buf_state.blames = {}
                return
            end
        end
        return
    end
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
    local bufs = state.bufs
    for buf, _ in pairs(bufs) do
        local bufnr = tonumber(buf)
        local filename = vim.api.nvim_buf_get_name(bufnr)
        if filename and filename ~= '' then
            local err, blames = git.buffer_blames(filename)
            if not err then
                state.blames_enabled = true
                local buf_state = get_buf_state(buf)
                if buf_state then
                    buf_state.blames = blames
                    return
                end
            end
        end
    end
end)

M.buffer_preview = vim.schedule_wrap(function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local filename = vim.api.nvim_buf_get_name(buf)
    if not filename or filename == '' then
        return
    end
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
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
    local err, data = git.buffer_diff(vim.api.nvim_buf_get_name(buf), hunks)
    if err then
        return
    end
    ui.show_diff(
        data.cwd_lines,
        data.origin_lines,
        data.lnum_changes,
        filetype
    )
end)

M.buffer_reset = function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    if #hunks == 0 then
        return
    end
    local err = git.buffer_reset(vim.api.nvim_buf_get_name(buf))
    if not err then
        vim.api.nvim_command('e!')
        buf_state.hunks = {}
        ui.hide_hunk_signs(buf)
    end
end

M.setup = function(config)
    state = configurer.assign(state, config)
    git.setup(config)
    ui.setup(config)
    vim.api.nvim_command('augroup tanvirtin/vgit | autocmd! | augroup END')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufEnter,BufWritePost * lua require("vgit")._buf_attach()')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufWipeout * lua require("vgit")._buf_detach()')
    vim.api.nvim_command('autocmd tanvirtin/vgit VimLeavePre * lua require("vgit")._tear_down()')
    if state.blames_enabled then
        vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
    end
   vim.cmd('command! -nargs=+ VGit lua require("vgit")._run_command(<f-args>)')
end

return M
