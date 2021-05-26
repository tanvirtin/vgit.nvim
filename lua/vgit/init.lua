local git = require('vgit.git')
local ui = require('vgit.ui')
local fs = require('vgit.fs')
local defer = require('vgit.defer')
local configurer = require('vgit.configurer')
local highlighter = require('vgit.highlighter')
local logger = require('plenary.log')

local vim = vim

local function get_initial_state()
    return {
        bufs = {},
        files = {},
        config = {},
        disabled = false,
        instantiated = false,
        hunks_enabled = true,
        blames_enabled = true,
    }
end

local M = {}

local state = get_initial_state()

local function create_buf_state(buf)
    local buf_state = {
        hunks = {},
        blames = {},
        disabled = false,
        last_lnum = 1,
        blame_is_shown = false,
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

local function correct_filename(filename)
    if filename == '' then
        return filename
    end
    local err, candidates = git.ls()
    if not err then
        for i = #filename, 1, -1 do
            local letter = filename:sub(i, i)
            local new_candidates = {}
            for _, candidate in ipairs(candidates) do
                local corrected_index = #candidate - (#filename - i)
                local candidate_letter = candidate:sub(corrected_index, corrected_index)
                if letter == candidate_letter then
                    table.insert(new_candidates, candidate)
                end
            end
            candidates = new_candidates
        end
    end
    return candidates[1] or filename
end

M._buf_attach = defer.throttle_leading(vim.schedule_wrap(function(buf)
    buf = buf or vim.api.nvim_get_current_buf()
    local filename = fs.filename(buf)
    if not filename or filename == '' then
        return
    end
    if not git.is_inside_work_tree() then
        state.disabled = true
        return
    else
        state.disabled = false
    end
    local buf_state = create_buf_state(buf)
    if state.hunks_enabled then
        local hunks_err, hunks = git.hunks(filename)
        if not hunks_err then
            buf_state.hunks = hunks
            ui.hide_hunk_signs(buf)
            ui.show_hunk_signs(buf, hunks)
        end
    end
    if state.blames_enabled then
        local blames_err, blames = git.blames(filename)
        if not blames_err then
            buf_state.blames = blames
        end
    end
    local logs_err, logs = git.logs(filename)
    if not logs_err then
        buf_state.logs = logs
    end
end), 50)

M._buf_detach = function(buf)
    if state.disabled == true then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    if get_buf_state(buf) then
        clear_buf_state(buf)
    end
end

M._blame_line = vim.schedule_wrap(function(buf)
    if state.disabled == true then
        return
    end
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
    ui.show_blame(buf, buf_state.blames, git.state.config)
    buf_state.blame_is_shown = true
end)

M._unblame_line = function(buf, override)
    if state.disabled == true then
        return
    end
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
    if state.disabled == true then
        return
    end
    local starts_with = command:sub(1, 1)
    if starts_with == '_' or not M[command] then
        logger.error('Invalid command for VGit')
        return
    end
    local success, _ = pcall(M[command], ...)
    if not success then
        logger.error('Failed to run command for VGit')
    end
end

M._run_submodule_command = function(name, command, ...)
    if state.disabled == true then
        return
    end
    local submodules = {
        ui = ui,
    }
    local submodule = submodules[name]
    local starts_with = command:sub(1, 1)
    if not submodule and starts_with == '_' or not submodule[command] then
        logger.error('Invalid submodule command for VGit')
        return
    end
    local success, _ = pcall(submodule[command], ...)
    if not success then
        logger.error('Failed to run submodule command for VGit')
    end
end

M._change_history = vim.schedule_wrap(function(current_buf, wins_to_update, bufs_to_update)
    if state.disabled == true then
        return
    end
    local selected_log = vim.api.nvim_win_get_cursor(0)[1]
    local filename = fs.filename(current_buf)
    local buf_state = get_buf_state(current_buf)
    if not buf_state then
        return
    end
    local logs = buf_state.logs
    local log = logs[selected_log]
    local hunks = nil
    local commit_hash = nil
    if log then
        local hunks_err, computed_hunks = git.hunks(filename, log.parent_hash, log.commit_hash)
        if hunks_err then
            return
        end
        hunks = computed_hunks
        commit_hash = log.commit_hash
    end
    if not filename or filename == '' then
        return
    end
    local err
    local lines
    if commit_hash then
        err, lines = git.show(correct_filename(filename), commit_hash)
    else
        err, lines = fs.read_file(filename);
    end
    if err then
        return err, nil
    end
    local diff_err, data = git.diff(lines, hunks)
    if not diff_err then
        ui.change_history(
            wins_to_update,
            bufs_to_update,
            selected_log,
            data.current_lines,
            data.previous_lines,
            data.lnum_changes
        )
    end
end)

M.hunk_preview = vim.schedule_wrap(function(buf, win)
    if state.disabled == true then
        return
    end
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
        ui.show_hunk(selected_hunk, vim.api.nvim_buf_get_option(buf, 'filetype'))
    end
end)

M.hunk_down = function(buf, win)
    if state.disabled == true then
        return
    end
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
    if state.disabled == true then
        return
    end
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
    if state.disabled == true then
        return
    end
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

M.hunks_quickfix_list = vim.schedule_wrap(function()
    if state.disabled == true then
        return
    end
    local err, filenames = git.ls()
    if not err then
        local qf_entries = {}
        for _, filename in ipairs(filenames) do
            local hunks_err, hunks = git.hunks(filename)
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
end)

M.diff = M.hunks_quickfix_list

M.toggle_buffer_hunks = vim.schedule_wrap(function()
    if state.disabled == true then
        return
    end
    if state.hunks_enabled then
        state.hunks_enabled = false
        local bufs = state.bufs
        for buf, _ in pairs(bufs) do
            local buf_state = get_buf_state(buf)
            if buf_state then
                buf_state.hunks = {}
                ui.hide_hunk_signs(buf)
            end
        end
        return
    else
        state.hunks_enabled = true
    end
    local bufs = state.bufs
    for buf, _ in pairs(bufs) do
        local bufnr = tonumber(buf)
        local filename = fs.filename(bufnr)
        if filename and filename ~= '' then
            local hunks_err, hunks = git.hunks(filename)
            if not hunks_err then
                state.hunks_enabled = true
                local buf_state = get_buf_state(buf)
                if buf_state then
                    buf_state.hunks = hunks
                    ui.show_hunk_signs(bufnr, hunks)
                end
            end
        end
    end
end)

M.toggle_buffer_blames = vim.schedule_wrap(function()
    if state.disabled == true then
        return
    end
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
            end
        end
        return
    else
        state.blames_enabled = true
    end
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
    vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
    local bufs = state.bufs
    for buf, _ in pairs(bufs) do
        local bufnr = tonumber(buf)
        local filename = fs.filename(bufnr)
        if filename and filename ~= '' then
            local err, blames = git.blames(filename)
            if not err then
                state.blames_enabled = true
                local buf_state = get_buf_state(buf)
                if buf_state then
                    buf_state.blames = blames
                end
            end
        end
    end
end)

M.buffer_history = vim.schedule_wrap(function(buf)
    if state.disabled == true then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    local filename = fs.filename(buf)
    if not filename or filename == '' then
        return
    end
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local logs = buf_state.logs
    local hunks = buf_state.hunks
    local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
    local err, lines = fs.read_file(filename);
    if not err then
        local diff_err, data = git.diff(lines, hunks)
        if not diff_err then
            ui.show_history(
                data.current_lines,
                data.previous_lines,
                logs,
                data.lnum_changes,
                filetype
            )
        end
    end
end)

M.buffer_preview = vim.schedule_wrap(function(buf)
    if state.disabled == true then
        return
    end
    if state.hunks_enabled then
        buf = buf or vim.api.nvim_get_current_buf()
        local filename = fs.filename(buf)
        local buf_state = get_buf_state(buf)
        if not buf_state then
            return
        end
        local hunks = buf_state.hunks
        if hunks and #hunks > 0 and filename and filename ~= '' then
            local filetype = vim.api.nvim_buf_get_option(buf, 'filetype')
            local err, lines = fs.read_file(filename);
            if not err then
                local diff_err, data = git.diff(lines, hunks)
                if not diff_err then
                    ui.show_preview(
                        data.current_lines,
                        data.previous_lines,
                        data.lnum_changes,
                        filetype
                    )
                end
            end
        end
    end
end)

M.buffer_reset = function(buf)
    if state.disabled == true then
        return
    end
    buf = buf or vim.api.nvim_get_current_buf()
    local buf_state = get_buf_state(buf)
    if not buf_state then
        return
    end
    local hunks = buf_state.hunks
    if #hunks == 0 then
        return
    end
    local filename = fs.filename(buf)
    local err = git.reset(filename)
    if not err then
        vim.api.nvim_command('e!')
        buf_state.hunks = {}
        ui.hide_hunk_signs(buf)
    end
end

M.setup = function(config)
    if not state.instantiated then
        state.instantiated = true
    else
        return
    end
    state = configurer.assign(state, config)
    highlighter.setup(config)
    git.setup(config)
    ui.setup(config)
    vim.api.nvim_command('augroup tanvirtin/vgit | autocmd! | augroup END')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufEnter,BufWritePost * lua require("vgit")._buf_attach()')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufWipeout * lua require("vgit")._buf_detach()')
    if state.blames_enabled then
        vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
    end
   vim.cmd('command! -nargs=+ VGit lua require("vgit")._run_command(<f-args>)')
   local err, files = git.ls()
   if not err then
        state.files = files
   end
end

return M
