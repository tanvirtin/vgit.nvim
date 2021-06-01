local git = require('vgit.git')
local ui = require('vgit.ui')
local fs = require('vgit.fs')
local highlighter = require('vgit.highlighter')
local State = require('vgit.State')
local Bstate = require('vgit.Bstate')
local buffer = require('vgit.buffer')
local throttle_leading = require('vgit.defer').throttle_leading
local logger = require('plenary.log')
local a = require('plenary.async_lib.async')
local t = require('vgit.localization').translate
local async_void = a.async_void
local await = a.await
local scheduler = a.scheduler

local vim = vim

local M = {}

local throttle_ms = 300
local bstate = Bstate.new()
local state = State.new({
    config = {},
    tracked_files = {},
    disabled = false,
    instantiated = false,
    hunks_enabled = true,
    blames_enabled = true,
    processing = false,
    are_files_tracked = false,
})

local function attach_blames_autocmd(buf)
    local f = string.format
    vim.cmd(f('aug tanvirtin/vgit/%s | autocmd! | aug END', buf))
    vim.cmd(f('au tanvirtin/vgit/%s CursorHold <buffer=%s> :lua require("vgit")._blame_line(%s)', buf, buf, buf))
    vim.cmd(f('au tanvirtin/vgit/%s CursorMoved <buffer=%s> :lua require("vgit")._unblame_line(%s)', buf, buf, buf))
end

local function detach_blames_autocmd(buf)
    vim.cmd(string.format('aug tanvirtin/vgit/%s | au! | aug END', buf))
end

M._buf_attach = async_void(function(buf)
    buf = buf or buffer.current()
    if buffer.is_valid(buf) then
        local filename = fs.filename(buf)
        if filename and filename ~= '' then
            local is_inside_work_tree = await(git.is_inside_work_tree())
            await(scheduler())
            if not is_inside_work_tree then
                state:set('disabled', true)
            else
                if state:get('disabled') == true then
                    state:set('disabled', false)
                end
                if not state:get('are_files_tracked') then
                    local tracked_files_err, tracked_files = await(git.ls_tracked())
                    await(scheduler())
                    if not tracked_files_err then
                        state:set('tracked_files', tracked_files)
                        state:set('are_files_tracked', true)
                    else
                        logger.error(t('errors/setup_tracked_file'))
                    end
                end
                local tracked_files = state:get('tracked_files')
                local buf_just_cached = false
                local buf_is_cached = bstate:contains(buf)
                if not buf_is_cached then
                    local project_relative_filename = fs.project_relative_filename(filename, tracked_files)
                    if project_relative_filename and project_relative_filename ~= '' then
                        bstate:add(buf)
                        buf_just_cached = true
                        bstate:set(buf, 'filename', filename)
                        bstate:set(buf, 'project_relative_filename', project_relative_filename)
                        if state:get('blames_enabled') then
                            attach_blames_autocmd(buf)
                        end
                        vim.api.nvim_buf_attach(buf, false, {
                            on_detach = function(_, cbuf)
                                if bstate:contains(cbuf) then
                                    bstate:remove(cbuf)
                                    detach_blames_autocmd(cbuf)
                                end
                            end,
                        })
                        await(scheduler())
                    end
                end
                if (buf_is_cached or buf_just_cached) and state:get('hunks_enabled') then
                    local err, hunks = await(git.hunks(filename))
                    await(scheduler())
                    if not err then
                        bstate:set(buf, 'hunks', hunks)
                        ui.hide_hunk_signs(buf)
                        ui.show_hunk_signs(buf, hunks)
                    else
                        logger.error(t('errors/buf_attach_hunks', filename))
                    end
                end
            end
        end
    end
end)

M._buf_update = async_void(function(buf)
    buf = buf or buffer.current()
    if state:get('hunks_enabled') and buffer.is_valid(buf) and bstate:contains(buf) then
        local filename = bstate:get(buf, 'filename')
        local err, hunks = await(git.hunks(filename))
        await(scheduler())
        if not err then
            bstate:set(buf, 'hunks', hunks)
            ui.hide_hunk_signs(buf)
            ui.show_hunk_signs(buf, hunks)
            await(scheduler())
        else
            logger.error(t('errors/buf_attach_hunks', filename))
        end
    end
end)

M._blame_line = async_void(throttle_leading(function(buf)
    if not state:get('disabled')
        and not state:get('processing')
        and buffer.is_valid(buf)
        and bstate:contains(buf) then
        local is_buf_modified = vim.api.nvim_buf_get_option(buf, 'modified')
        if not is_buf_modified then
            local win = vim.api.nvim_get_current_win()
            local last_lnum_blamed = bstate:get(buf, 'last_lnum_blamed')
            local lnum = vim.api.nvim_win_get_cursor(win)[1]
            if last_lnum_blamed ~= lnum then
                local filename = bstate:get(buf, 'filename')
                state:set('processing', true)
                local err, blame = await(git.blame_line(filename, lnum))
                state:set('processing', false)
                await(scheduler())
                if not err then
                    if not state:get('processing') then
                        ui.hide_blame(buf)
                        if vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] == lnum then
                            ui.show_blame(buf, blame, lnum, git.state:get('config'))
                            bstate:set(buf, 'last_lnum_blamed', lnum)
                        end
                        await(scheduler())
                    end
                else
                    logger.error(t('errors/blame_line', filename))
                end
            end
        end
    end
end, throttle_ms))

M._unblame_line = throttle_leading(function(buf, override)
    if bstate:contains(buf) and buffer.is_valid(buf) then
        if override then
            return ui.hide_blame(buf)
        end
        local win = vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        local last_lnum_blamed = bstate:get(buf, 'last_lnum_blamed')
        if lnum ~= last_lnum_blamed then
            ui.hide_blame(buf)
        end
    end
end, throttle_ms)

M._run_command = function(command, ...)
    if not state:get('disabled') then
        local starts_with = command:sub(1, 1)
        if starts_with == '_' or not M[command] or not type(M[command]) == 'function' then
            logger.error(t('errors/invalid_command'))
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
            logger.error(t('errors/invalid_submodule_command'))
            return
        end
        return submodule[command](...)
    end
end

M._change_history = async_void(throttle_leading(function(buf, wins_to_update, bufs_to_update)
    if not state:get('disabled') and buffer.is_valid(buf) then
        local selected_log = vim.api.nvim_win_get_cursor(0)[1]
        if bstate:contains(buf) then
            local filename = bstate:get(buf, 'filename')
            local logs = bstate:get(buf, 'logs')
            local log = logs[selected_log]
            local hunks = nil
            local commit_hash = nil
            if log then
                local err, computed_hunks = await(git.hunks(filename, log.parent_hash, log.commit_hash))
                await(scheduler())
                if err then
                    logger.error(t('errors/change_history_hunks', log.parent_hash, log.commit_hash))
                    return
                end
                hunks = computed_hunks
                commit_hash = log.commit_hash
            end
            local err
            local lines
            if commit_hash then
                local project_filename = bstate:get(buf, 'project_relative_filename')
                err, lines = await(git.show(project_filename, commit_hash))
                await(scheduler())
            else
                err, lines = fs.read_file(filename);
            end
            if err then
                logger.error(t('errors/change_history_show'))
                return
            end
            local diff_err, data = await(git.vertical_diff(lines, hunks))
            await(scheduler())
            if not diff_err then
                ui.change_history(
                    wins_to_update,
                    bufs_to_update,
                    selected_log,
                    data.current_lines,
                    data.previous_lines,
                    data.lnum_changes
                )
                await(scheduler())
            else
                logger.error(t('errors/change_history_diff'))
            end
        end
    end
end, throttle_ms))

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

M.hunk_preview = throttle_leading(function(buf, win)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
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
end, throttle_ms)

M.hunk_down = function(buf, win)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
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
                    vim.cmd('norm! zz')
                else
                    vim.api.nvim_win_set_cursor(win, { hunks[1].start, 0 })
                    vim.cmd('norm! zz')
                end
            end
        end
    end
end

M.hunk_up = function(buf, win)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
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
                    vim.cmd('norm! zz')
                else
                    vim.api.nvim_win_set_cursor(win, { hunks[#hunks].finish, 0 })
                    vim.cmd('norm! zz')
                end
            end
        end
    end
end

M.hunk_reset = throttle_leading(function(buf, win)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
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
                    vim.cmd('update')
                    table.remove(hunks, selected_hunk_index)
                    ui.hide_hunk_signs(buf)
                    ui.show_hunk_signs(buf, hunks)
                end
            end
        end
    end
end, throttle_ms)

M.hunks_quickfix_list = async_void(throttle_leading(function()
    if not state:get('disabled') then
        local qf_entries = {}
        local filenames = state:get('tracked_files')
        for _, filename in ipairs(filenames) do
            local hunks_err, hunks = await(git.hunks(filename))
            await(scheduler())
            if not hunks_err then
                for _, hunk in ipairs(hunks) do
                    table.insert(qf_entries, {
                        text = hunk.header,
                        filename = filename,
                        lnum = hunk.start,
                        col = 0,
                    })
                end
            else
                logger.error(t('errors/quickfix_list_hunks'))
            end
        end
        vim.fn.setqflist(qf_entries, 'r')
        vim.cmd('copen')
    end
end, throttle_ms))

M.diff = M.hunks_quickfix_list

M.toggle_buffer_hunks = async_void(throttle_leading(function()
    if not state:get('disabled') then
        if state:get('hunks_enabled') then
            state:set('hunks_enabled', false)
            bstate:for_each_buf(function(buf, buf_state)
                if buffer.is_valid(buf) then
                    buf_state:set('hunks', {})
                    ui.hide_hunk_signs(buf)
                end
            end)
            return state:get('hunks_enabled')
        else
            state:set('hunks_enabled', true)
        end
        bstate:for_each_buf(function(buf, buf_state)
            if buffer.is_valid(buf) then
                local filename = bstate:get(buf, 'filename')
                local hunks_err, hunks = await(git.hunks(filename))
                await(scheduler())
                if not hunks_err then
                    state:set('hunks_enabled', true)
                    buf_state:set('hunks', hunks)
                    ui.show_hunk_signs(buf, hunks)
                else
                    logger.error(t('errors/toggle_buffer_hunks', filename))
                end
            end
        end)
    end
    return state:get('hunks_enabled')
end, throttle_ms))

M.toggle_buffer_blames = async_void(throttle_leading(function()
    if not state:get('disabled') then
        vim.cmd('aug tanvirtin/vgit/blame | autocmd! | aug END')
        if state:get('blames_enabled') then
            state:set('blames_enabled', false)
            bstate:for_each_buf(function(buf, buf_state)
                if buffer.is_valid(buf) then
                    detach_blames_autocmd(buf)
                    local bufnr = tonumber(buf)
                    buf_state:set('blames', {})
                    M._unblame_line(bufnr, true)
                end
            end)
            return state:get('blames_enabled')
        else
            state:set('blames_enabled', true)
        end
        bstate:for_each_buf(function(buf, buf_state)
            if buffer.is_valid(buf) then
                local win = vim.api.nvim_get_current_win()
                local lnum = vim.api.nvim_win_get_cursor(win)[1]
                local filename = buf_state:get('filename')
                local err, blame = await(git.blame_line(filename, lnum))
                attach_blames_autocmd(buf)
                await(scheduler())
                if not err then
                    ui.hide_blame(buf)
                    if vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] == lnum then
                        ui.show_blame(buf, blame, lnum, git.state:get('config'))
                    end
                else
                    logger.error(t('errors/toggle_buffer_blames', filename))
                end
            end
        end)
        return state:get('blames_enabled')
    end
end, throttle_ms))

M.buffer_history = async_void(throttle_leading(function(buf)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
        if bstate:contains(buf) then
            local filename = bstate:get(buf, 'filename')
            local logs_err, logs = await(git.logs(filename))
            await(scheduler())
            if not logs_err then
                bstate:set(buf, 'logs', logs)
                local hunks = bstate:get(buf, 'hunks')
                local filetype = fs.filetype(buf)
                local err, lines = fs.read_file(filename);
                if not err then
                    local diff_err, data = await(git.vertical_diff(lines, hunks))
                    await(scheduler())
                    if not diff_err then
                        ui.show_history(
                            data.current_lines,
                            data.previous_lines,
                            logs,
                            data.lnum_changes,
                            filetype
                        )
                        await(scheduler())
                    else
                        logger.error(t('errors/buffer_history_diff', filename))
                    end
                else
                    logger.error(t('errors/buffer_history_file', filename))
                end
            else
                logger.error(t('errors/buffer_history_logs', filename))
            end
        end
    end
end, throttle_ms))

M.buffer_preview = async_void(throttle_leading(function(buf)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
        if state:get('hunks_enabled') then
            if bstate:contains(buf) then
                local filename = bstate:get(buf, 'filename')
                local hunks = bstate:get(buf, 'hunks')
                if hunks and #hunks > 0 and filename and filename ~= '' then
                    local filetype = fs.filetype(buf)
                    local err, lines = fs.read_file(filename);
                    if not err then
                        local diff_err, data = await(git.vertical_diff(lines, hunks))
                        await(scheduler())
                        if not diff_err then
                            ui.show_preview(
                                data.current_lines,
                                data.previous_lines,
                                data.lnum_changes,
                                filetype
                            )
                            await(scheduler())
                        else
                            logger.error(t('errors/buffer_preview_diff', filename))
                        end
                    end
                end
            end
        end
    end
end, throttle_ms))

M.buffer_reset = async_void(throttle_leading(function(buf)
    buf = buf or buffer.current()
    if not state:get('disabled') and buffer.is_valid(buf) then
        if bstate:contains(buf) then
            local hunks = bstate:get(buf, 'hunks')
            if #hunks ~= 0 then
                local filename = bstate:get(buf, 'filename')
                local err = await(git.reset(filename))
                await(scheduler())
                if not err then
                    vim.cmd('e!')
                else
                    logger.error(t('errors/buffer_reset', filename))
                end
            end
        end
    end
end, throttle_ms))

M.enabled = function()
    return not state:get('disabled')
end

M.instantiated = function()
    return state:get('instantiated')
end

M.apply_highlights = function()
    ui.apply_highlights()
end

M.setup = async_void(function(config)
    if state:get('instantiated') then
        return
    else
        state:set('instantiated', true)
    end
    state:assign(config)
    highlighter.setup(config)
    await(git.setup(config))
    await(scheduler())
    ui.setup(config)
    vim.cmd('aug tanvirtin/vgit | autocmd! | aug END')
    vim.cmd('au tanvirtin/vgit BufWinEnter * lua require("vgit")._buf_attach()')
    vim.cmd('au tanvirtin/vgit BufWrite * lua require("vgit")._buf_update()')
    vim.cmd(string.format(
        'com! -nargs=+ %s %s',
        '-complete=customlist,v:lua.package.loaded.vgit._command_autocompletes',
        'VGit lua require("vgit")._run_command(<f-args>)'
    ))
end)

return M
