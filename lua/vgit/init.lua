local git = require('vgit.git')
local ui = require('vgit.ui')
local fs = require('vgit.fs')
local defer = require('vgit.defer')
local highlighter = require('vgit.highlighter')
local State = require('vgit.State')
local Bstate = require('vgit.Bstate')
local logger = require('plenary.log')
local async_lib = require('plenary.async_lib')
local async_void = async_lib.async_void
local await = async_lib.await
local scheduler = async_lib.scheduler

local vim = vim

local M = {}

local bstate = Bstate.new()
local state = State.new({
    config = {},
    tracked_files = {},
    untracked_files = {},
    disabled = false,
    instantiated = false,
    hunks_enabled = true,
    blames_enabled = true,
})

M._buf_attach = defer.throttle_leading(async_void(function(buf)
    await(scheduler())
    if not git.is_inside_work_tree() then
        state:set('disabled', true)
    else
        buf = buf or vim.api.nvim_get_current_buf()
        local filename = fs.filename(buf)
        if filename and filename ~= '' then
            bstate:add(buf)
            if state:get('hunks_enabled') then
                local hunks_err, hunks = git.hunks(filename)
                if not hunks_err then
                    bstate:set(buf, 'hunks', hunks)
                    ui.hide_hunk_signs(buf)
                    ui.show_hunk_signs(buf, hunks)
                end
            end
            if state:get('blames_enabled') then
                local blames_err, blames = git.blames(filename)
                if not blames_err then
                    bstate:set(buf, 'blames', blames)
                end
            end
            local logs_err, logs = git.logs(filename)
            if not logs_err then
                bstate:set(buf, 'logs', logs)
            end
        end
        if state:get('disabled') == true then
            state:set('disabled', false)
        end
    end
end), 50)

M._buf_detach = defer.throttle_leading(async_void(function(buf)
    await(scheduler())
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        if bstate:contains(buf) then
            bstate:remove(buf)
        end
    end
end), 50)

M._blame_line = async_void(function(buf)
    await(scheduler())
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        if bstate:contains(buf) then
            local blames = bstate:get(buf, 'blames')
            if #blames ~= 0 then
                local is_buf_modified = vim.api.nvim_buf_get_option(buf, 'modified')
                if not is_buf_modified then
                    local win = vim.api.nvim_get_current_win()
                    local lnum = vim.api.nvim_win_get_cursor(win)[1]
                    bstate:set(buf, 'last_lnum', lnum)
                    ui.show_blame(buf, blames, git.state:get('config'))
                    bstate:set(buf, 'blame_is_shown', true)
                end
            end
        end
    end
end)

M._unblame_line = function(buf, override)
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        if bstate:contains(buf) then
            if bstate:get(buf, 'blame_is_shown') then
                local win = vim.api.nvim_get_current_win()
                local lnum = vim.api.nvim_win_get_cursor(win)[1]
                if override then
                    ui.hide_blame(buf)
                    bstate:set(buf, 'blame_is_shown', false)
                    return
                end
                if bstate:get(buf, 'last_lnum') ~= lnum then
                    ui.hide_blame(buf)
                    bstate:set(buf, 'blame_is_shown', false)
                end
            end
        end
    end
end

M._run_command = function(command, ...)
    if not state:get('disabled') then
        local starts_with = command:sub(1, 1)
        if starts_with == '_' or not M[command] or not type(M[command]) == 'function' then
            logger.error('Invalid command for VGit')
            return
        end
        return M[command](...)
    end
end

M._run_submodule_command = function(name, command, ...)
    if not state:get('disabled') then
        local submodules = { ui = ui }
        local submodule = submodules[name]
        local starts_with = command:sub(1, 1)
        if not submodule and starts_with == '_'
            or not submodule[command]
            or not type(submodule[command]) == 'function' then
            logger.error('Invalid submodule command for VGit')
            return
        end
        return submodule[command](...)
    end
end

M._change_history = async_void(function(buf, wins_to_update, bufs_to_update)
    await(scheduler())
    if not state:get('disabled') then
        local selected_log = vim.api.nvim_win_get_cursor(0)[1]
        local filename = fs.filename(buf)
        if bstate:contains(buf) then
            local logs = bstate:get(buf, 'logs')
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
                err, lines = git.show(fs.project_relative_path(filename, state:get('tracked_files')), commit_hash)
            else
                err, lines = fs.read_file(filename);
            end
            if err then
                return
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
        end
    end
end)

M._command_autocompletes = function(arglead, line)
    local parsed_line = #vim.split(line, '%s+')
    local matches = {}
    if parsed_line == 2 then
        for func, _ in pairs(M) do
            if not vim.startswith(func, '_') and vim.startswith(func, arglead) then
                table.insert(matches, func)
            end
        end
    end
    return matches
end

M.hunk_preview = async_void(function(buf, win)
    await(scheduler())
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        win = win or vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        local selected_hunk = nil
        if bstate:contains(buf) then
            local hunks = bstate:get(buf, 'hunks')
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
        end
    end
end)

M.hunk_down = function(buf, win)
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        win = win or vim.api.nvim_get_current_win()
        if bstate:contains(buf) then
            local hunks = bstate:get(buf, 'hunks')
            if #hunks ~= 0 then
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
        end
    end
end

M.hunk_up = function(buf, win)
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        win = win or vim.api.nvim_get_current_win()
        if bstate:contains(buf) then
            local hunks = bstate:get(buf, 'hunks')
            if #hunks ~= 0 then
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
        end
    end
end

M.hunk_reset = async_void(function(buf, win)
    await(scheduler)
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        win = win or vim.api.nvim_get_current_win()
        if bstate:contains(buf) then
            local hunks = bstate:get(buf, 'hunks')
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
    end
end)

M.hunks_quickfix_list = async_void(function()
    await(scheduler())
    if not state:get('disabled') then
        local qf_entries = {}
        local filenames = state:get('tracked_files')
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

M.toggle_buffer_hunks = async_void(function()
    await(scheduler())
    if not state:get('disabled') then
        if state:get('hunks_enabled') then
            state:set('hunks_enabled', false)
            bstate:for_each_buf(function(buf, buf_state)
                buf_state:set('hunks', {})
                ui.hide_hunk_signs(buf)
            end)
            return state:get('hunks_enabled')
        else
            state:set('hunks_enabled', true)
        end
        bstate:for_each_buf(function(buf, buf_state)
            local filename = fs.filename(buf)
            if filename and filename ~= '' then
                local hunks_err, hunks = git.hunks(filename)
                if not hunks_err then
                    state:set('hunks_enabled', true)
                    buf_state:set('hunks', hunks)
                    ui.show_hunk_signs(buf, hunks)
                end
            end
        end)
    end
    return state:get('hunks_enabled')
end)

M.toggle_buffer_blames = async_void(function()
    await(scheduler())
    if not state:get('disabled') then
        vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
        if state:get('blames_enabled') then
            state:set('blames_enabled', false)
            bstate:for_each_buf(function(buf, buf_state)
                local bufnr = tonumber(buf)
                buf_state:set('blames', {})
                M._unblame_line(bufnr, true)
            end)
            return state:get('blames_enabled')
        else
            state:set('blames_enabled', true)
        end
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
        bstate:for_each_buf(function(buf, buf_state)
            local bufnr = tonumber(buf)
            local filename = fs.filename(bufnr)
            if filename and filename ~= '' then
                local err, blames = git.blames(filename)
                if not err then
                    state:set('blames_enabled', true)
                    buf_state:set('hunks', blames)
                end
            end
        end)
        return state:get('blames_enabled')
    end
end)

M.buffer_history = async_void(function(buf)
    await(scheduler())
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        local filename = fs.filename(buf)
        if not filename or filename == '' then
            return
        end
        local logs = bstate:get(buf, 'logs')
        local hunks = bstate:get(buf, 'hunks')
        local filetype = fs.filetype(buf)
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
    end
end)

M.buffer_preview = async_void(function(buf)
    await(scheduler())
    if not state:get('disabled') then
        if state:get('hunks_enabled') then
            buf = buf or vim.api.nvim_get_current_buf()
            local filename = fs.filename(buf)
            local hunks = bstate:get(buf, 'hunks')
            if hunks and #hunks > 0 and filename and filename ~= '' then
                local filetype = fs.filetype(buf)
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
    end
end)

M.buffer_reset = async_void(function(buf)
    await(scheduler())
    if not state:get('disabled') then
        buf = buf or vim.api.nvim_get_current_buf()
        local hunks = bstate:get(buf, 'hunks')
        if #hunks ~= 0 then
            local filename = fs.filename(buf)
            local err = git.reset(filename)
            if not err then
                vim.api.nvim_command('e!')
                bstate:set(buf, 'hunks', {})
                ui.hide_hunk_signs(buf)
            end
        end
    end
end)

M.enabled = function()
    return not state:get('disabled')
end

M.instantiated = function()
    return state:get('instantiated')
end

M.setup = async_void(function(config)
    await(scheduler())
    if state:get('instantiated') then
        return
    else
        state:set('instantiated', true)
    end
    state:assign(config)
    highlighter.setup(config)
    git.setup(config)
    ui.setup(config)
    vim.api.nvim_command('augroup tanvirtin/vgit | autocmd! | augroup END')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufEnter,BufWritePost * lua require("vgit")._buf_attach()')
    vim.api.nvim_command('autocmd tanvirtin/vgit BufWipeout * lua require("vgit")._buf_detach()')
    if state:get('blames_enabled') then
        vim.api.nvim_command('augroup tanvirtin/vgit/blame | autocmd! | augroup END')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorHold * lua require("vgit")._blame_line()')
        vim.api.nvim_command('autocmd tanvirtin/vgit/blame CursorMoved * lua require("vgit")._unblame_line()')
    end
    vim.cmd(string.format(
        'com! -nargs=+ %s %s',
        '-complete=customlist,v:lua.package.loaded.vgit._command_autocompletes',
        'VGit lua require("vgit")._run_command(<f-args>)'
    ))
    local tracked_files_err, tracked_files = git.ls_tracked()
    if not tracked_files_err then
        state:set('tracked_files', tracked_files)
    end
    local untracked_files_err, untracked_files = git.ls_untracked()
    if not untracked_files_err then
        state:set('untracked_files', untracked_files)
    end
end)

return M
