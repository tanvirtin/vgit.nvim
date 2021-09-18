local git = require('vgit.git')
local themes = require('vgit.themes')
local layouts = require('vgit.layouts')
local renderer = require('vgit.renderer')
local highlight = require('vgit.highlight')
local events = require('vgit.events')
local sign = require('vgit.sign')
local key_mapper = require('vgit.key_mapper')
local controller_store = require('vgit.stores.controller_store')
local render_store = require('vgit.stores.render_store')
local logger = require('vgit.logger')
local dimensions = require('vgit.dimensions')
local fs = require('vgit.fs')
local preview_store = require('vgit.stores.preview_store')
local buffer = require('vgit.buffer')
local throttle_leading = require('vgit.defer').throttle_leading
local navigation = require('vgit.navigation')
local Patch = require('vgit.Patch')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local debounce_trailing = require('vgit.defer').debounce_trailing
local Hunk = require('vgit.Hunk')
local utils = require('vgit.utils')
local change = require('vgit.change')
local wrap = require('plenary.async.async').wrap

local M = {}

local store_buf = function(buf, filename, tracked_filename, tracked_remote_filename)
    buffer.store.add(buf)
    local filetype = fs.filetype(buf)
    if not filetype or filetype == '' then
        filetype = fs.detect_filetype(filename)
    end
    buffer.store.set(buf, 'filetype', filetype)
    buffer.store.set(buf, 'filename', filename)
    if tracked_filename and tracked_filename ~= '' then
        buffer.store.set(buf, 'tracked_filename', tracked_filename)
        buffer.store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
        return
    end
    buffer.store.set(buf, 'untracked', true)
end

local attach_blames_autocmd = function(buf)
    events.buf.on(buf, 'CursorHold', string.format(':lua _G.package.loaded.vgit._blame_line(%s)', buf))
    events.buf.on(buf, 'CursorMoved', string.format(':lua _G.package.loaded.vgit._unblame_line(%s)', buf))
end

local detach_blames_autocmd = function(buf)
    events.off(string.format('%s/CursorHold', buf))
    events.off(string.format('%s/CursorMoved', buf))
end

local get_hunk_calculator = function()
    return (controller_store.get('diff_strategy') == 'remote' and git.remote_hunks) or git.index_hunks
end

local calculate_hunks = function(buf)
    return get_hunk_calculator()(buffer.store.get(buf, 'tracked_filename'))
end

local get_current_hunk = function(hunks, lnum)
    for i = 1, #hunks do
        local hunk = hunks[i]
        if lnum == 1 and hunk.start == 0 and hunk.finish == 0 then
            return hunk
        end
        if lnum >= hunk.start and lnum <= hunk.finish then
            return hunk
        end
    end
end

local function ext_hunk_generation(buf, original_lines, current_lines)
    scheduler()
    if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer.store.contains(buf) then
        return
    end
    local temp_filename_b = fs.tmpname()
    local temp_filename_a = fs.tmpname()
    fs.write_file(temp_filename_a, original_lines)
    scheduler()
    fs.write_file(temp_filename_b, current_lines)
    scheduler()
    local hunks_err, hunks = git.file_hunks(temp_filename_a, temp_filename_b)
    scheduler()
    if not hunks_err then
        if not buffer.store.contains(buf) then
            fs.remove_file(temp_filename_a)
            scheduler()
            fs.remove_file(temp_filename_b)
            scheduler()
            return
        end
        buffer.store.set(buf, 'hunks', hunks)
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, hunks)
    else
        logger.debug(hunks_err, 'init.lua/ext_hunk_generation')
    end
    fs.remove_file(temp_filename_a)
    scheduler()
    fs.remove_file(temp_filename_b)
    scheduler()
end

local function int_hunk_generation(buf, original_lines, current_lines)
    scheduler()
    if controller_store.get('disabled') then
        return
    end
    if not buffer.is_valid(buf) then
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    local o_lines_str = ''
    local c_lines_str = ''
    local num_lines = math.max(#original_lines, #current_lines)
    for i = 1, num_lines do
        local o_line = original_lines[i]
        local c_line = current_lines[i]
        if o_line then
            o_lines_str = o_lines_str .. original_lines[i] .. '\n'
        end
        if c_line then
            c_lines_str = c_lines_str .. current_lines[i] .. '\n'
        end
    end
    local hunks = {}
    vim.diff(o_lines_str, c_lines_str, {
        on_hunk = void(function(start_o, count_o, start_c, count_c)
            scheduler()
            local hunk = Hunk:new({ { start_o, count_o }, { start_c, count_c } })
            hunks[#hunks + 1] = hunk
            if count_o > 0 then
                for i = start_o, start_o + count_o - 1 do
                    hunk.diff[#hunk.diff + 1] = '-' .. (original_lines[i] or '')
                end
            end
            if count_c > 0 then
                for i = start_c, start_c + count_c - 1 do
                    hunk.diff[#hunk.diff + 1] = '+' .. (current_lines[i] or '')
                end
            end
        end),
        algorithm = 'myers',
    })
    buffer.store.set(buf, 'hunks', hunks)
    renderer.hide_hunk_signs(buf)
    renderer.render_hunk_signs(buf, hunks)
end

local generate_tracked_hunk_signs = debounce_trailing(
    void(function(buf)
        scheduler()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        local max_lines_limit = controller_store.get('predict_hunk_max_lines')
        if vim.api.nvim_buf_line_count(buf) > max_lines_limit then
            return
        end
        local tracked_filename = buffer.store.get(buf, 'tracked_filename')
        local tracked_remote_filename = buffer.store.get(buf, 'tracked_remote_filename')
        local show_err, original_lines
        if controller_store.get('diff_strategy') == 'remote' then
            show_err, original_lines = git.show(tracked_remote_filename, git.get_diff_base())
        else
            show_err, original_lines = git.show(tracked_remote_filename, '')
        end
        scheduler()
        if
            show_err
            and vim.startswith(show_err[1], string.format('fatal: path \'%s\' exists on disk', tracked_filename))
        then
            original_lines = {}
            show_err = nil
        end
        if show_err then
            return logger.debug(show_err, 'init.lua/generate_tracked_hunk_signs')
        end
        local current_lines = buffer.get_lines(buf)
        buffer.store.set(buf, 'temp_lines', current_lines)
        if vim.diff then
            int_hunk_generation(buf, original_lines, current_lines)
        else
            ext_hunk_generation(buf, original_lines, current_lines)
        end
    end),
    controller_store.get('predict_hunk_throttle_ms')
)

local generate_untracked_hunk_signs = debounce_trailing(
    void(function(buf)
        scheduler()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        local hunks = git.untracked_hunks(buffer.get_lines(buf))
        scheduler()
        if not buffer.store.contains(buf) then
            return
        end
        buffer.store.set(buf, 'hunks', hunks)
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, hunks)
    end),
    controller_store.get('predict_hunk_throttle_ms')
)

local function buf_attach_tracked(buf)
    scheduler()
    if controller_store.get('disabled') then
        return
    end
    if not buffer.is_valid(buf) then
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    if controller_store.get('blames_enabled') then
        attach_blames_autocmd(buf)
    end
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = void(function(_, cbuf, _, _, p_lnum, n_lnum, byte_count)
            scheduler()
            if
                not controller_store.get('predict_hunk_signs')
                or (p_lnum == n_lnum and byte_count == 0)
                or not controller_store.get('hunks_enabled')
            then
                return
            end
            generate_tracked_hunk_signs(cbuf)
        end),
        on_detach = void(function()
            scheduler()
            buf_attach_tracked(buf)
        end),
    })
    if not controller_store.get('hunks_enabled') then
        return
    end
    local err, hunks = calculate_hunks(buf)
    scheduler()
    if err then
        logger.debug(err, 'init.lua/buf_attach_tracked')
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    buffer.store.set(buf, 'hunks', hunks)
    renderer.render_hunk_signs(buf, hunks)
end

local function buf_attach_untracked(buf)
    if controller_store.get('disabled') then
        return
    end
    if not buffer.is_valid(buf) then
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = void(function(_, cbuf, _, _, p_lnum, n_lnum, byte_count)
            scheduler()
            if
                not controller_store.get('predict_hunk_signs')
                or (p_lnum == n_lnum and byte_count == 0)
                or not controller_store.get('hunks_enabled')
                or not buffer.store.contains(cbuf)
            then
                return
            end
            if not buffer.store.get(cbuf, 'untracked') then
                return generate_tracked_hunk_signs(cbuf)
            end
            generate_untracked_hunk_signs(cbuf)
        end),
        on_detach = void(function()
            scheduler()
            buf_attach_untracked(buf)
        end),
    })
    if not controller_store.get('hunks_enabled') then
        return
    end
    local hunks = git.untracked_hunks(buffer.get_lines(buf))
    scheduler()
    if not buffer.store.contains(buf) then
        return
    end
    buffer.store.set(buf, 'hunks', hunks)
    renderer.render_hunk_signs(buf, hunks)
end

M._buf_attach = void(function(buf)
    scheduler()
    buf = buf or buffer.current()
    if not buffer.is_valid(buf) then
        return
    end
    if buffer.store.contains(buf) then
        return
    end
    local filename = fs.filename(buf)
    scheduler()
    if not filename or filename == '' then
        return
    end
    if not fs.exists(filename) then
        return
    end
    local is_inside_work_tree = git.is_inside_work_tree()
    scheduler()
    if not is_inside_work_tree then
        controller_store.set('disabled', true)
        return
    end
    if controller_store.get('disabled') == true then
        controller_store.set('disabled', false)
    end
    local tracked_filename = git.tracked_filename(filename)
    scheduler()
    local tracked_remote_filename = git.tracked_remote_filename(filename)
    scheduler()
    if tracked_filename and tracked_filename ~= '' then
        store_buf(buf, filename, tracked_filename, tracked_remote_filename)
        return buf_attach_tracked(buf)
    end
    if controller_store.get('diff_strategy') == 'index' and controller_store.get('show_untracked_file_signs') then
        local is_ignored = git.check_ignored(filename)
        scheduler()
        if not is_ignored then
            store_buf(buf, filename, tracked_filename, tracked_remote_filename)
            buf_attach_untracked(buf)
        end
    end
end)

M._rerender_history = throttle_leading(
    void(function(buf)
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        local selected_log = vim.api.nvim_win_get_cursor(0)[1]
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.rerender_history_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local logs = buffer.store.get(buf, 'logs')
                local log = logs[selected_log]
                local err, hunks, lines, commit_hash, computed_hunks
                if not log then
                    return { 'Failed to access logs' }, nil
                end
                if selected_log == 1 then
                    local temp_lines = buffer.store.get(buf, 'temp_lines')
                    if #temp_lines ~= 0 then
                        lines = temp_lines
                        computed_hunks = buffer.store.get(buf, 'hunks')
                    else
                        err, computed_hunks = git.remote_hunks(tracked_filename, 'HEAD')
                    end
                else
                    err, computed_hunks = git.remote_hunks(tracked_filename, log.parent_hash, log.commit_hash)
                end
                scheduler()
                if err then
                    logger.debug(err, 'init.lua/_rerender_history')
                    return err, nil
                end
                hunks = computed_hunks
                commit_hash = log.commit_hash
                if commit_hash and not lines then
                    err, lines = git.show(buffer.store.get(buf, 'tracked_remote_filename'), commit_hash)
                    scheduler()
                elseif not lines then
                    err, lines = fs.read_file(tracked_filename)
                    scheduler()
                end
                if err then
                    logger.debug(err, 'init.lua/_rerender_history')
                    return err, nil
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        logs = logs,
                        diff_change = data,
                    })
            end, 0),
            selected_log
        )
    end),
    controller_store.get('action_delay_ms')
)

M._rerender_project_diff = throttle_leading(
    void(function()
        if controller_store.get('disabled') then
            return
        end
        local selected_file = vim.api.nvim_win_get_cursor(0)[1]
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.rerender_project_diff_preview(
            wrap(function()
                local changed_files_err, changed_files = git.ls_changed()
                scheduler()
                if changed_files_err then
                    logger.debug(changed_files_err, 'init.lua/_rerender_project_diff')
                    return changed_files_err, nil
                end
                local file = changed_files[selected_file]
                if not file then
                    return { 'File not found' },
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local filename = file.filename
                local hunk_calculator = get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/_rerender_project_diff')
                    return hunks_err, nil
                end
                local files_err, lines = fs.read_file(filename)
                if files_err then
                    logger.debug(files_err, 'init.lua/_rerender_project_diff')
                    return files_err,
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        changed_files = changed_files,
                        diff_change = data,
                        filetype = fs.detect_filetype(filename),
                    })
            end, 0),
            selected_file
        )
    end),
    controller_store.get('action_delay_ms')
)

M._buf_update = void(function(buf)
    scheduler()
    buf = buf or buffer.current()
    if not buffer.is_valid(buf) then
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    buffer.store.set(buf, 'temp_lines', {})
    if controller_store.get('hunks_enabled') then
        if
            buffer.store.get(buf, 'untracked')
            and controller_store.get('diff_strategy') == 'index'
            and controller_store.get('show_untracked_file_signs')
        then
            local hunks = git.untracked_hunks(buffer.get_lines(buf))
            scheduler()
            if not buffer.store.contains(buf) then
                return
            end
            buffer.store.set(buf, 'hunks', hunks)
            renderer.hide_hunk_signs(buf)
            renderer.render_hunk_signs(buf, hunks)
            return
        end
        local err, hunks = calculate_hunks(buf)
        scheduler()
        if err then
            return logger.debug(err, 'init.lua/_buf_update')
        end
        if not buffer.store.contains(buf) then
            return
        end
        buffer.store.set(buf, 'hunks', hunks)
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, hunks)
    end
end)

M._buf_detach = function(buf)
    buf = buf or buffer.current()
    if not buffer.store.contains(buf) then
        return
    end
    buffer.store.remove(buf)
    detach_blames_autocmd(buf)
end

M._blame_line = debounce_trailing(
    void(function(buf)
        scheduler()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        local win = vim.api.nvim_get_current_win()
        local last_lnum_blamed = buffer.store.get(buf, 'last_lnum_blamed')
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        if last_lnum_blamed == lnum then
            return
        end
        local err, blame = git.blame_line(buffer.store.get(buf, 'tracked_filename'), lnum)
        scheduler()
        if err then
            return logger.debug(err, 'init.lua/_blame_line')
        end
        if not buffer.store.contains(buf) then
            return
        end
        renderer.hide_blame_line(buf)
        scheduler()
        if vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] == lnum then
            renderer.render_blame_line(buf, blame, lnum, git.state:get('config'))
            scheduler()
            if not buffer.store.contains(buf) then
                return
            end
            buffer.store.set(buf, 'last_lnum_blamed', lnum)
        end
        scheduler()
    end),
    controller_store.get('blame_line_throttle_ms')
)

M._unblame_line = void(function(buf, override)
    if not buffer.is_valid(buf) then
        return
    end
    if not buffer.store.contains(buf) then
        return
    end
    if buffer.store.get(buf, 'untracked') then
        return
    end
    if override then
        return renderer.hide_blame_line(buf)
    end
    local win = vim.api.nvim_get_current_win()
    local lnum = vim.api.nvim_win_get_cursor(win)[1]
    local last_lnum_blamed = buffer.store.get(buf, 'last_lnum_blamed')
    if lnum ~= last_lnum_blamed then
        renderer.hide_blame_line(buf)
    end
end)

M._keep_focused = function()
    if not preview_store.exists() then
        return
    end
    local preview = preview_store.get()
    if not preview:is_mounted() then
        return
    end
    preview:keep_focused()
end

M._run_command = function(command, ...)
    if controller_store.get('disabled') then
        return
    end
    local vgit = require('vgit')
    if not command then
        -- TODO: Show help doc
        return
    end
    local starts_with = command:sub(1, 1)
    if starts_with == '_' or not vgit[command] or not type(vgit[command]) == 'function' then
        -- TODO: Show help doc
        logger.error(string.format('Invalid command', command))
        return
    end
    return vgit[command](...)
end

M._command_autocompletes = function(arglead, line)
    local vgit = require('vgit')
    local parsed_line = #vim.split(line, '%s+')
    local matches = {}
    if parsed_line == 2 then
        for func, _ in pairs(vgit) do
            if not vim.startswith(func, '_') and vim.startswith(func, arglead) then
                matches[#matches + 1] = func
            end
        end
    end
    return matches
end

M.buffer_reset = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks ~= 0 then
            local tracked_remote_filename = buffer.store.get(buf, 'tracked_remote_filename')
            if controller_store.get('diff_strategy') == 'remote' then
                local err, lines = git.show(tracked_remote_filename, 'HEAD')
                scheduler()
                if not err then
                    logger.debug(err, 'init.lua/buffer_reset')
                    return
                end
                buffer.set_lines(buf, lines)
                vim.cmd('update')
                return
            end
            local err, lines = git.show(tracked_remote_filename, '')
            scheduler()
            if err then
                return logger.debug(err, 'init.lua/buffer_reset')
            end
            buffer.set_lines(buf, lines)
            vim.cmd('update')
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_hunk_stage = throttle_leading(
    void(function(buf, win)
        scheduler()
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        if controller_store.get('diff_strategy') ~= 'index' then
            return
        end
        -- If buffer is untracked then, the whole file is the hunk.
        if buffer.store.get(buf, 'untracked') then
            local filename = buffer.store.get(buf, 'filename')
            local err = git.stage_file(filename)
            scheduler()
            if err then
                logger.debug(err, 'init.lua/buffer_hunk_stage')
                return
            end
            local tracked_filename = git.tracked_filename(filename)
            scheduler()
            local tracked_remote_filename = git.tracked_remote_filename(filename)
            scheduler()
            if not buffer.store.contains(buf) then
                return
            end
            buffer.store.set(buf, 'tracked_filename', tracked_filename)
            buffer.store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
            buffer.store.set(buf, 'hunks', {})
            buffer.store.set(buf, 'untracked', false)
            renderer.hide_hunk_signs(buf)
            renderer.render_hunk_signs(buf, {})
            return
        end
        win = win or vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        local hunks = buffer.store.get(buf, 'hunks')
        local selected_hunk = get_current_hunk(hunks, lnum)
        if not selected_hunk then
            return
        end
        local tracked_filename = buffer.store.get(buf, 'tracked_filename')
        local tracked_remote_filename = buffer.store.get(buf, 'tracked_remote_filename')
        local patch = Patch:new(tracked_remote_filename, selected_hunk)
        local patch_filename = fs.tmpname()
        fs.write_file(patch_filename, patch)
        scheduler()
        local err = git.stage_hunk_from_patch(patch_filename)
        scheduler()
        fs.remove_file(patch_filename)
        scheduler()
        if err then
            logger.debug(err, 'init.lua/buffer_hunk_stage')
            return
        end
        local hunks_err, calculated_hunks = git.index_hunks(tracked_filename)
        scheduler()
        if hunks_err then
            logger.debug(err, 'init.lua/buffer_hunk_stage')
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        buffer.store.set(buf, 'hunks', calculated_hunks)
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, calculated_hunks)
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_stage = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        if controller_store.get('diff_strategy') ~= 'index' then
            return
        end
        local filename = buffer.store.get(buf, 'filename')
        local tracked_filename = buffer.store.get(buf, 'tracked_filename')
        local err = git.stage_file((tracked_filename and tracked_filename ~= '' and tracked_filename) or filename)
        scheduler()
        if err then
            logger.debug(err, 'init.lua/buffer_stage')
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            tracked_filename = git.tracked_filename(filename)
            scheduler()
            local tracked_remote_filename = git.tracked_remote_filename(filename)
            scheduler()
            if not buffer.store.contains(buf) then
                return
            end
            buffer.store.set(buf, 'tracked_filename', tracked_filename)
            buffer.store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
            buffer.store.set(buf, 'untracked', false)
        end
        buffer.store.set(buf, 'hunks', {})
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, {})
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_unstage = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.is_being_edited(buf) then
            return
        end
        if controller_store.get('diff_strategy') ~= 'index' then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local filename = buffer.store.get(buf, 'filename')
        local tracked_filename = buffer.store.get(buf, 'tracked_filename')
        local err = git.unstage_file(tracked_filename)
        scheduler()
        if err then
            logger.debug(err, 'init.lua/buffer_unstage')
            return
        end
        tracked_filename = git.tracked_filename(filename)
        scheduler()
        local tracked_remote_filename = git.tracked_remote_filename(filename)
        scheduler()
        if not buffer.store.contains(buf) then
            return
        end
        buffer.store.set(buf, 'tracked_filename', tracked_filename)
        buffer.store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
        if tracked_filename and tracked_filename ~= '' then
            buffer.store.set(buf, 'untracked', false)
            local hunks_err, calculated_hunks = git.index_hunks(tracked_filename)
            scheduler()
            if not hunks_err then
                buffer.store.set(buf, 'hunks', calculated_hunks)
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, calculated_hunks)
            else
                logger.debug(err, 'init.lua/buffer_unstage')
            end
        else
            buffer.store.set(buf, 'untracked', true)
            local hunks = git.untracked_hunks(buffer.get_lines(buf))
            scheduler()
            if not buffer.store.contains(buf) then
                return
            end
            buffer.store.set(buf, 'hunks', hunks)
            renderer.hide_hunk_signs(buf)
            renderer.render_hunk_signs(buf, hunks)
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_hunk_reset = throttle_leading(
    void(function(buf, win)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not controller_store.get('hunks_enabled') then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        win = win or vim.api.nvim_get_current_win()
        local hunks = buffer.store.get(buf, 'hunks')
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        if lnum == 1 then
            local current_lines = buffer.get_lines(buf)
            if #hunks > 0 and #current_lines == 1 and current_lines[1] == '' then
                local all_removes = true
                for i = 1, #hunks do
                    local hunk = hunks[i]
                    if hunk.type ~= 'remove' then
                        all_removes = false
                        break
                    end
                end
                if all_removes then
                    return M.buffer_reset(buf)
                end
            end
        end
        local selected_hunk = nil
        local selected_hunk_index = nil
        for i = 1, #hunks do
            local hunk = hunks[i]
            if
                (lnum >= hunk.start and lnum <= hunk.finish)
                or (hunk.start == 0 and hunk.finish == 0 and lnum - 1 == hunk.start and lnum - 1 == hunk.finish)
            then
                selected_hunk = hunk
                selected_hunk_index = i
                break
            end
        end
        if selected_hunk then
            local replaced_lines = {}
            for i = 1, #selected_hunk.diff do
                local line = selected_hunk.diff[i]
                local is_line_removed = vim.startswith(line, '-')
                if is_line_removed then
                    replaced_lines[#replaced_lines + 1] = string.sub(line, 2, -1)
                end
            end
            local start = selected_hunk.start
            local finish = selected_hunk.finish
            if start and finish then
                if selected_hunk.type == 'remove' then
                    vim.api.nvim_buf_set_lines(buf, start, finish, false, replaced_lines)
                else
                    vim.api.nvim_buf_set_lines(buf, start - 1, finish, false, replaced_lines)
                end
                local new_lnum = start
                if new_lnum < 1 then
                    new_lnum = 1
                end
                navigation.set_cursor(win, { new_lnum, 0 })
                vim.cmd('update')
                table.remove(hunks, selected_hunk_index)
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, hunks)
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.toggle_buffer_hunks = throttle_leading(
    void(function()
        scheduler()
        if not controller_store.get('disabled') then
            if controller_store.get('hunks_enabled') then
                controller_store.set('hunks_enabled', false)
                buffer.store.for_each(function(buf, bcache)
                    if buffer.is_valid(buf) then
                        bcache:set('hunks', {})
                        renderer.hide_hunk_signs(buf)
                    end
                end)
                return controller_store.get('hunks_enabled')
            else
                controller_store.set('hunks_enabled', true)
            end
            buffer.store.for_each(function(buf, bcache)
                if buffer.is_valid(buf) then
                    local hunks_err, hunks = calculate_hunks(buf)
                    scheduler()
                    if not hunks_err then
                        controller_store.set('hunks_enabled', true)
                        bcache:set('hunks', hunks)
                        renderer.hide_hunk_signs(buf)
                        renderer.render_hunk_signs(buf, hunks)
                    else
                        logger.debug(hunks_err, 'init.lua/toggle_buffer_hunks')
                    end
                end
            end)
        end
        return controller_store.get('hunks_enabled')
    end),
    controller_store.get('action_delay_ms')
)

M.toggle_buffer_blames = throttle_leading(
    void(function()
        scheduler()
        if controller_store.get('disabled') then
            return
        end
        if controller_store.get('blames_enabled') then
            controller_store.set('blames_enabled', false)
            buffer.store.for_each(function(buf, bcache)
                if buffer.is_valid(buf) then
                    detach_blames_autocmd(buf)
                    bcache:set('blames', {})
                    M._unblame_line(buf, true)
                end
            end)
            return controller_store.get('blames_enabled')
        end
        controller_store.set('blames_enabled', true)
        buffer.store.for_each(function(buf)
            if buffer.is_valid(buf) then
                attach_blames_autocmd(buf)
            end
        end)
        return controller_store.get('blames_enabled')
    end),
    controller_store.get('action_delay_ms')
)

M.toggle_diff_preference = throttle_leading(function()
    local allowed_preference = {
        horizontal = 'vertical',
        vertical = 'horizontal',
    }
    controller_store.set('diff_preference', allowed_preference[controller_store.get('diff_preference')])
end, controller_store.get(
    'action_delay_ms'
))

M.hunk_down = void(function(buf, win)
    scheduler()
    buf = buf or buffer.current()
    if controller_store.get('disabled') then
        return
    end
    if preview_store.exists() then
        local preview = preview_store.get()
        return preview:mark_down()
    end
    if buffer.is_valid(buf) then
        if not buffer.store.contains(buf) then
            return
        end
        win = win or vim.api.nvim_get_current_win()
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks ~= 0 then
            navigation.hunk_down({ win }, hunks)
            scheduler()
        end
    end
end)

M.hunk_up = void(function(buf, win)
    scheduler()
    buf = buf or buffer.current()
    if controller_store.get('disabled') then
        return
    end
    if preview_store.exists() then
        local preview = preview_store.get()
        return preview:mark_up()
    end
    if buffer.is_valid(buf) then
        if not buffer.store.contains(buf) then
            return
        end
        win = win or vim.api.nvim_get_current_win()
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks ~= 0 then
            navigation.hunk_up({ win }, hunks)
            scheduler()
        end
    end
end)

M.apply_highlights = function()
    highlight.setup(controller_store.get('config'), true)
end

M.show_debug_logs = function()
    if logger.state:get('debug') then
        local debug_logs = logger.state:get('debug_logs')
        for i = 1, #debug_logs do
            local log = debug_logs[i]
            logger.error(log)
        end
    end
end

M.get_diff_base = function()
    return git.get_diff_base()
end

M.get_diff_strategy = function()
    return controller_store.get('diff_strategy')
end

M.get_diff_preference = function()
    return controller_store.get('diff_preference')
end

M.set_diff_base = throttle_leading(
    void(function(diff_base)
        scheduler()
        if not diff_base or type(diff_base) ~= 'string' then
            logger.error(string.format('Failed to set diff base, the commit "%s" is invalid', diff_base))
            return
        end
        if git.controller_store.get('diff_base') == diff_base then
            return
        end
        local is_commit_valid = git.is_commit_valid(diff_base)
        scheduler()
        if not is_commit_valid then
            logger.error(string.format('Failed to set diff base, the commit "%s" is invalid', diff_base))
            return
        end
        git.set_diff_base(diff_base)
        if controller_store.get('diff_strategy') ~= 'remote' then
            return
        end
        local data = buffer.store.get_data()
        for buf, bcache in pairs(data) do
            local hunks_err, hunks = git.remote_hunks(bcache:get('tracked_filename'))
            scheduler()
            if hunks_err then
                logger.debug(hunks_err, 'init.lua/set_diff_base')
            else
                bcache:set('hunks', hunks)
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, hunks)
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.set_diff_preference = throttle_leading(function(preference)
    if preference ~= 'horizontal' and preference ~= 'vertical' then
        return logger.error(string.format('Failed to set diff preferece, "%s" is invalid', preference))
    end
    local current_preference = controller_store.get('diff_preference')
    if current_preference == preference then
        return
    end
    controller_store.set('diff_preference', preference)
end, controller_store.get(
    'action_delay_ms'
))

M.set_diff_strategy = throttle_leading(
    void(function(strategy)
        scheduler()
        if strategy ~= 'remote' and strategy ~= 'index' then
            return logger.error(string.format('Failed to set diff strategy, "%s" is invalid', strategy))
        end
        local current_strategy = controller_store.get('diff_strategy')
        if current_strategy == strategy then
            return
        end
        controller_store.set('diff_strategy', strategy)
        buffer.store.for_each(function(buf, bcache)
            if buffer.is_valid(buf) then
                local hunks_err, hunks = calculate_hunks(buf)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/set_diff_strategy')
                else
                    controller_store.set('hunks_enabled', true)
                    bcache:set('hunks', hunks)
                    renderer.hide_hunk_signs(buf)
                    renderer.render_hunk_signs(buf, hunks)
                end
            end
        end)
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_gutter_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        renderer.render_gutter_blame_preview(
            wrap(function()
                local filename = buffer.store.get(buf, 'tracked_filename')
                local read_file_err, lines = fs.read_file(filename)
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_gutter_blame_preview')
                    return read_file_err, nil
                end
                local blames_err, blames = git.blames(filename)
                scheduler()
                if blames_err then
                    logger.debug(blames_err, 'init.lua/buffer_gutter_blame_preview')
                    return blames_err, nil
                end
                local hunk_calculator = get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_gutter_blame_preview')
                    return hunks_err, nil
                end
                return nil,
                    {
                        blames = blames,
                        lines = lines,
                        hunks = hunks,
                    }
            end, 0),
            buffer.store.get(buf, 'filetype')
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local has_commits = git.has_commits()
        scheduler()
        if not has_commits then
            return
        end
        local win = vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        renderer.render_blame_preview(wrap(function()
            local err, blame = git.blame_line(buffer.store.get(buf, 'tracked_filename'), lnum)
            scheduler()
            return err, blame
        end, 0))
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_history_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_history_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local logs_err, logs = git.logs(tracked_filename)
                scheduler()
                if logs_err then
                    logger.debug(logs_err, 'init.lua/buffer_history_preview')
                    return logs_err, nil
                end
                buffer.store.set(buf, 'logs', logs)
                local temp_lines = buffer.store.get(buf, 'temp_lines')
                if #temp_lines ~= 0 then
                    local lines = temp_lines
                    local hunks = buffer.store.get(buf, 'hunks')
                    local data = calculate_change(lines, hunks)
                    return nil,
                        utils.readonly({
                            logs = logs,
                            diff_change = data,
                        })
                end
                local read_file_err, lines = fs.read_file(tracked_filename)
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_history_preview')
                    return read_file_err, nil
                end
                local hunks_err, hunks = git.remote_hunks(tracked_filename, 'HEAD')
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_history_preview')
                    return hunks_err, nil
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        logs = logs,
                        diff_change = data,
                    })
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_hunk_preview = throttle_leading(
    void(function(buf, win)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if not controller_store.get('hunks_enabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local hunks = buffer.store.get(buf, 'hunks')
        if #hunks == 0 then
            logger.info('No changes found')
            return
        end
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        renderer.render_hunk_preview(
            wrap(function()
                local read_file_err, lines = fs.read_file(buffer.store.get(buf, 'tracked_filename'))
                scheduler()
                if read_file_err then
                    logger.debug(read_file_err, 'init.lua/buffer_hunk_preview')
                    return read_file_err, nil
                end
                local data = change.horizontal(lines, hunks)
                return nil,
                    {
                        diff_change = data,
                        selected_hunk = get_current_hunk(hunks, lnum) or Hunk:new(),
                    }
            end, 0),
            buffer.store.get(buf, 'filetype')
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if not buffer.store.contains(buf) then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_diff_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local hunks_err, hunks = calculate_hunks(buf)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_diff_preview')
                    return hunks_err, nil
                end
                local temp_lines = buffer.store.get(buf, 'temp_lines')
                local read_file_err, lines
                if #temp_lines ~= 0 then
                    lines = temp_lines
                else
                    read_file_err, lines = fs.read_file(tracked_filename)
                    scheduler()
                    if read_file_err then
                        logger.debug(read_file_err, 'init.lua/buffer_diff_preview')
                        return read_file_err, nil
                    end
                end
                local data = calculate_change(lines, hunks)
                scheduler()
                return nil, {
                    diff_change = data,
                }
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_staged_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if controller_store.get('disabled') then
            return
        end
        if not buffer.is_valid(buf) then
            return
        end
        if not buffer.store.contains(buf) then
            return
        end
        if buffer.store.get(buf, 'untracked') then
            return
        end
        if controller_store.get('diff_strategy') ~= 'index' then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        renderer.render_diff_preview(
            wrap(function()
                local tracked_filename = buffer.store.get(buf, 'tracked_filename')
                local hunks_err, hunks = git.staged_hunks(tracked_filename)
                scheduler()
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/buffer_staged_diff_preview')
                    return hunks_err, nil
                end
                scheduler()
                local show_err, lines = git.show(buffer.store.get(buf, 'tracked_remote_filename'))
                scheduler()
                if show_err then
                    logger.debug(show_err, 'init.lua/buffer_staged_diff_preview')
                    return show_err, nil
                end
                local data = calculate_change(lines, hunks)
                scheduler()
                return nil, {
                    diff_change = data,
                }
            end, 0),
            buffer.store.get(buf, 'filetype'),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.project_diff_preview = throttle_leading(
    void(function()
        if controller_store.get('disabled') then
            return
        end
        local diff_preference = controller_store.get('diff_preference')
        local calculate_change = (diff_preference == 'horizontal' and change.horizontal) or change.vertical
        local changed_files_err, changed_files = git.ls_changed()
        scheduler()
        if changed_files_err then
            return logger.debug(changed_files_err, 'init.lua/project_diff_preview')
        end
        if #changed_files == 0 then
            logger.info('No changes found')
            return
        end
        renderer.render_project_diff_preview(
            wrap(function()
                local selected_file = 1
                local file = changed_files[selected_file]
                if not file then
                    return { 'File not found' },
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local filename = file.filename
                local hunk_calculator = get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                if hunks_err then
                    logger.debug(hunks_err, 'init.lua/project_diff_preview')
                    return hunks_err, nil
                end
                local files_err, lines = fs.read_file(filename)
                if files_err then
                    logger.debug(files_err, 'init.lua/project_diff_preview')
                    return files_err,
                        utils.readonly({
                            changed_files = changed_files,
                        })
                end
                local data = calculate_change(lines, hunks)
                return nil,
                    utils.readonly({
                        changed_files = changed_files,
                        diff_change = data,
                        filetype = fs.detect_filetype(filename),
                    })
            end, 0),
            diff_preference
        )
    end),
    controller_store.get('action_delay_ms')
)

M.project_hunks_qf = throttle_leading(
    void(function()
        if not controller_store.get('disabled') then
            local qf_entries = {}
            local err, filenames = git.ls_changed()
            scheduler()
            if err then
                return logger.debug(err, 'init.lua/project_hunks_qf')
            end
            for i = 1, #filenames do
                local filename = filenames[i].filename
                local hunk_calculator = get_hunk_calculator()
                local hunks_err, hunks = hunk_calculator(filename)
                scheduler()
                if not hunks_err then
                    for j = 1, #hunks do
                        local hunk = hunks[j]
                        qf_entries[#qf_entries + 1] = {
                            text = string.format('[%s..%s]', hunk.start, hunk.finish),
                            filename = filename,
                            lnum = hunk.start,
                            col = 0,
                        }
                    end
                else
                    logger.debug(hunks_err, 'init.lua/project_hunks_qf')
                end
            end
            if #qf_entries ~= 0 then
                vim.fn.setqflist(qf_entries, 'r')
                vim.cmd('copen')
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.actions = function()
    if not pcall(require, 'telescope') then
        logger.info('Please install https://github.com/nvim-telescope/telescope.nvim to use the command palette')
        return
    end
    local actions = {
        'project_diff_preview | Opens preview of all the changes in your current project',
        'project_hunks_qf | Opens quickfix list with all the changes as hunks in your current project',
        'buffer_diff_preview | Opens preview of the changes in the current buffer',
        'buffer_staged_diff_preview | Opens preview of all the staged changes for your current buffer',
        'buffer_hunk_preview | Opens preview of the changes in the current buffer hunk',
        'buffer_history_preview | Opens preview of all the changes throughout time for the current buffer',
        'buffer_blame_preview | Opens preview of showing the blame details of the current line for the current buffer',
        'buffer_gutter_blame_preview | Opens preview of showing all blame details for the current buffer',
        'buffer_reset | Reset all the changes on the current buffer',
        'buffer_hunk_stage | Stage the current hunk the cursor is currently on in your current buffer',
        'buffer_stage | Stage the current buffer',
        'buffer_unstage | Unstage the current buffer',
        'buffer_hunk_reset | Reset the current hunk the cursor is onin your current buffer',
        'toggle_buffer_hunks | Enables buffer signs on/Disables buffer signs off',
        'toggle_buffer_blames | Enables current line blames/Disables current buffer line blames',
        'toggle_diff_preference | Toggles between "Horizontal" and "Vertical" diff preference',
        'hunk_up | Navigates up on to a change on any buffer or preview',
        'hunk_down | Navigates down on to a change on any buffer or preview',
        'apply_highlights | Applies all the current highlights, useful when changing colorschemes',
    }
    local pickers = require('telescope.pickers')
    local finders = require('telescope.finders')
    local conf = require('telescope.config').values
    local telescope_actions = require('telescope.actions')
    local action_state = require('telescope.actions.state')
    pickers.new({ layout_strategy = 'bottom_pane', layout_config = { height = #actions } }, {
        prompt_title = 'VGit',
        finder = finders.new_table(actions),
        sorter = conf.generic_sorter(),
        attach_mappings = function(buf, map)
            map(
                'i',
                '<cr>',
                void(function()
                    local selected = action_state.get_selected_entry()
                    local value = selected.value
                    local command = vim.trim(vim.split(value, '|')[1])
                    telescope_actions.close(buf)
                    scheduler()
                    require('vgit')[command]()
                end)
            )
            return true
        end,
    }):find()
end

M.renderer = renderer
M.events = events
M.highlight = highlight
M.themes = themes
M.layouts = layouts
M.dimensions = dimensions
M.utils = utils

M.setup = function(config)
    controller_store.setup(config)
    render_store.setup(config)
    events.setup()
    highlight.setup(config)
    sign.setup(config)
    logger.setup(config)
    git.setup(config)
    key_mapper.setup(config)
    events.on('BufWinEnter', ':lua _G.package.loaded.vgit._buf_attach()')
    events.on('BufWinLeave', ':lua _G.package.loaded.vgit._buf_detach()')
    events.on('BufWritePost', ':lua _G.package.loaded.vgit._buf_update()')
    events.on('WinEnter', ':lua _G.package.loaded.vgit._keep_focused()')
    vim.cmd(
        string.format(
            'command! -nargs=* -range %s %s',
            '-complete=customlist,v:lua.package.loaded.vgit._command_autocompletes',
            'VGit lua _G.package.loaded.vgit._run_command(<f-args>)'
        )
    )
    M._buf_attach()
end

return M
