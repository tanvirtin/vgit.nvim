local utils = require('vgit.utils')
local diff = require('vgit.diff')
local Hunk = require('vgit.Hunk')
local preview_store = require('vgit.stores.preview_store')
local git = require('vgit.git')
local themes = require('vgit.themes')
local layouts = require('vgit.layouts')
local renderer = require('vgit.renderer')
local fs = require('vgit.fs')
local highlight = require('vgit.highlight')
local events = require('vgit.events')
local sign = require('vgit.sign')
local buffer = require('vgit.buffer')
local key_mapper = require('vgit.key_mapper')
local throttle_leading = require('vgit.defer').throttle_leading
local controller_store = require('vgit.stores.controller_store')
local render_store = require('vgit.stores.render_store')
local debounce_trailing = require('vgit.defer').debounce_trailing
local logger = require('vgit.logger')
local dimensions = require('vgit.dimensions')
local navigation = require('vgit.navigation')
local Patch = require('vgit.Patch')
local wrap = require('plenary.async.async').wrap
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local buffer_store = require('vgit.stores.buffer_store')

local M = {}

local function cache_buf(buf, filename, tracked_filename, tracked_remote_filename)
    buffer_store.add(buf)
    local filetype = fs.filetype(buf)
    if not filetype or filetype == '' then
        filetype = fs.detect_filetype(filename)
    end
    buffer_store.set(buf, 'filetype', filetype)
    buffer_store.set(buf, 'filename', filename)
    if tracked_filename and tracked_filename ~= '' then
        buffer_store.set(buf, 'tracked_filename', tracked_filename)
        buffer_store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
    else
        buffer_store.set(buf, 'untracked', true)
    end
end

local function attach_blames_autocmd(buf)
    events.buf.on(buf, 'CursorHold', string.format(':lua require("vgit")._blame_line(%s)', buf))
    events.buf.on(buf, 'CursorMoved', string.format(':lua require("vgit")._unblame_line(%s)', buf))
end

local function detach_blames_autocmd(buf)
    events.off(string.format('%s/CursorHold', buf))
    events.off(string.format('%s/CursorMoved', buf))
end

local function get_hunk_calculator()
    return (controller_store.get('diff_strategy') == 'remote' and git.remote_hunks) or git.index_hunks
end

local function calculate_hunks(buf)
    return get_hunk_calculator()(buffer_store.get(buf, 'tracked_filename'))
end

local function get_current_hunk(hunks, lnum)
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
    if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer_store.contains(buf) then
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
        if not buffer_store.contains(buf) then
            fs.remove_file(temp_filename_a)
            scheduler()
            fs.remove_file(temp_filename_b)
            scheduler()
            return
        end
        buffer_store.set(buf, 'hunks', hunks)
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

local generate_tracked_hunk_signs = debounce_trailing(
    void(function(buf)
        scheduler()
        if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer_store.contains(buf) then
            return
        end
        local max_lines_limit = controller_store.get('predict_hunk_max_lines')
        if vim.api.nvim_buf_line_count(buf) > max_lines_limit then
            return
        end
        local tracked_filename = buffer_store.get(buf, 'tracked_filename')
        local tracked_remote_filename = buffer_store.get(buf, 'tracked_remote_filename')
        local show_err, original_lines
        if controller_store.get('diff_strategy') == 'remote' then
            show_err, original_lines = git.show(tracked_remote_filename, M.get_diff_base())
        else
            show_err, original_lines = git.show(tracked_remote_filename, '')
        end
        scheduler()
        if show_err then
            local err = show_err[1]
            if vim.startswith(err, string.format('fatal: path \'%s\' exists on disk', tracked_filename)) then
                original_lines = {}
                show_err = nil
            end
        end
        if not show_err then
            if not buffer_store.contains(buf) then
                return
            end
            local current_lines = buffer.get_lines(buf)
            if not buffer_store.contains(buf) then
                return
            end
            buffer_store.set(buf, 'temp_lines', current_lines)
            ext_hunk_generation(buf, original_lines, current_lines)
        else
            logger.debug(show_err, 'init.lua/generate_tracked_hunk_signs')
        end
    end),
    controller_store.get('predict_hunk_throttle_ms')
)

local generate_untracked_hunk_signs = debounce_trailing(
    void(function(buf)
        scheduler()
        if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer_store.contains(buf) then
            return
        end
        local hunks = git.untracked_hunks(buffer.get_lines(buf))
        scheduler()
        if not buffer_store.contains(buf) then
            return
        end
        buffer_store.set(buf, 'hunks', hunks)
        renderer.hide_hunk_signs(buf)
        renderer.render_hunk_signs(buf, hunks)
    end),
    controller_store.get('predict_hunk_throttle_ms')
)

local buf_attach_tracked = void(function(buf)
    scheduler()
    if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer_store.contains(buf) then
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
                or not buffer_store.contains(buf)
            then
                return
            end
            generate_tracked_hunk_signs(cbuf)
        end),
        on_detach = function(_, cbuf)
            if buffer_store.contains(cbuf) then
                buffer_store.remove(cbuf)
                detach_blames_autocmd(cbuf)
            end
        end,
    })
    if controller_store.get('hunks_enabled') then
        local err, hunks = calculate_hunks(buf)
        scheduler()
        if not err then
            if not buffer_store.contains(buf) then
                return
            end
            buffer_store.set(buf, 'hunks', hunks)
            renderer.render_hunk_signs(buf, hunks)
        else
            logger.debug(err, 'init.lua/buf_attach_tracked')
        end
    end
end)

local function buf_attach_untracked(buf)
    if controller_store.get('disabled') or not buffer.is_valid(buf) or not buffer_store.contains(buf) then
        return
    end
    vim.api.nvim_buf_attach(buf, false, {
        on_lines = void(function(_, cbuf, _, _, p_lnum, n_lnum, byte_count)
            scheduler()
            if
                not controller_store.get('predict_hunk_signs')
                or (p_lnum == n_lnum and byte_count == 0)
                or not controller_store.get('hunks_enabled')
                or not buffer_store.contains(cbuf)
            then
                return
            end
            if not buffer_store.get(cbuf, 'untracked') then
                return generate_tracked_hunk_signs(cbuf)
            end
            generate_untracked_hunk_signs(cbuf)
        end),
        on_detach = function(_, cbuf)
            if buffer_store.contains(cbuf) then
                buffer_store.remove(cbuf)
            end
        end,
    })
    if controller_store.get('hunks_enabled') then
        local hunks = git.untracked_hunks(buffer.get_lines(buf))
        scheduler()
        if not buffer_store.contains(buf) then
            return
        end
        buffer_store.set(buf, 'hunks', hunks)
        renderer.render_hunk_signs(buf, hunks)
    end
end

M._buf_attach = void(function(buf)
    scheduler()
    buf = buf or buffer.current()
    if not buffer.is_valid(buf) then
        return
    end
    local filename = fs.filename(buf)
    if not filename or filename == '' or not fs.exists(filename) then
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
        cache_buf(buf, filename, tracked_filename, tracked_remote_filename)
        return buf_attach_tracked(buf)
    end
    if controller_store.get('diff_strategy') == 'index' and controller_store.get('show_untracked_file_signs') then
        local is_ignored = git.check_ignored(filename)
        scheduler()
        if not is_ignored then
            cache_buf(buf, filename, tracked_filename, tracked_remote_filename)
            buf_attach_untracked(buf)
        end
    end
end)

M._buf_update = void(function(buf)
    scheduler()
    buf = buf or buffer.current()
    if buffer.is_valid(buf) and buffer_store.contains(buf) then
        buffer_store.set(buf, 'temp_lines', {})
        if controller_store.get('hunks_enabled') then
            if
                buffer_store.get(buf, 'untracked')
                and controller_store.get('diff_strategy') == 'index'
                and controller_store.get('show_untracked_file_signs')
            then
                local hunks = git.untracked_hunks(buffer.get_lines(buf))
                scheduler()
                buffer_store.set(buf, 'hunks', hunks)
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, hunks)
                return
            end
            local err, hunks = calculate_hunks(buf)
            scheduler()
            if not err then
                buffer_store.set(buf, 'hunks', hunks)
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, hunks)
            else
                logger.debug(err, 'init.lua/_buf_update')
            end
        end
    end
end)

M._blame_line = debounce_trailing(
    void(function(buf)
        scheduler()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            if not buffer.get_option(buf, 'modified') then
                local win = vim.api.nvim_get_current_win()
                local last_lnum_blamed = buffer_store.get(buf, 'last_lnum_blamed')
                local lnum = vim.api.nvim_win_get_cursor(win)[1]
                if last_lnum_blamed ~= lnum then
                    local err, blame = git.blame_line(buffer_store.get(buf, 'tracked_filename'), lnum)
                    scheduler()
                    if not err then
                        renderer.hide_blame_line(buf)
                        scheduler()
                        if vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())[1] == lnum then
                            renderer.render_blame_line(buf, blame, lnum, git.state:get('config'))
                            scheduler()
                            buffer_store.set(buf, 'last_lnum_blamed', lnum)
                        end
                    else
                        logger.debug(err, 'init.lua/_blame_line')
                    end
                end
            end
        end
        scheduler()
    end),
    controller_store.get('blame_line_throttle_ms')
)

M._unblame_line = void(function(buf, override)
    if buffer_store.contains(buf) and buffer.is_valid(buf) and not buffer_store.get(buf, 'untracked') then
        if override then
            return renderer.hide_blame_line(buf)
        end
        local win = vim.api.nvim_get_current_win()
        local lnum = vim.api.nvim_win_get_cursor(win)[1]
        local last_lnum_blamed = buffer_store.get(buf, 'last_lnum_blamed')
        if lnum ~= last_lnum_blamed then
            renderer.hide_blame_line(buf)
        end
    end
end)

M._run_command = function(command, ...)
    if not controller_store.get('disabled') then
        local starts_with = command:sub(1, 1)
        if starts_with == '_' or not M[command] or not type(M[command]) == 'function' then
            logger.error(string.format('Invalid command %s', command))
            return
        end
        return M[command](...)
    end
end

M._command_autocompletes = function(arglead, line)
    local parsed_line = #vim.split(line, '%s+')
    local matches = {}
    if parsed_line == 2 then
        for func, _ in pairs(M) do
            if not vim.startswith(func, '_') and vim.startswith(func, arglead) then
                matches[#matches + 1] = func
            end
        end
    end
    return matches
end

M._rerender_history = throttle_leading(
    void(function(buf)
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            local selected_log = vim.api.nvim_win_get_cursor(0)[1]
            if selected_log == 1 then
                return
            else
                selected_log = selected_log - 1
            end
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
            renderer.rerender_history_preview(
                wrap(function()
                    local tracked_filename = buffer_store.get(buf, 'tracked_filename')
                    local logs = buffer_store.get(buf, 'logs')
                    local log = logs[selected_log]
                    local err, hunks, lines, commit_hash, computed_hunks
                    if log then
                        if selected_log == 1 then
                            local temp_lines = buffer_store.get(buf, 'temp_lines')
                            if #temp_lines ~= 0 then
                                lines = temp_lines
                                computed_hunks = buffer_store.get(buf, 'hunks')
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
                    else
                        return { 'Failed to access logs' }, nil
                    end
                    if commit_hash and not lines then
                        err, lines = git.show(buffer_store.get(buf, 'tracked_remote_filename'), commit_hash)
                        scheduler()
                    elseif not lines then
                        err, lines = fs.read_file(tracked_filename)
                        scheduler()
                    end
                    if err then
                        logger.debug(err, 'init.lua/_rerender_history')
                        return err, nil
                    end
                    local data = calculate_diff(lines, hunks)
                    return nil,
                        utils.readonly({
                            logs = logs,
                            diff_change = data,
                        })
                end, 0),
                selected_log
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M._rerender_project_diff = throttle_leading(
    void(function()
        local selected_file = vim.api.nvim_win_get_cursor(0)[1]
        if selected_file == 1 then
            return
        else
            selected_file = selected_file - 1
        end
        if not controller_store.get('disabled') then
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
            renderer.rerender_project_diff_preview(
                wrap(function()
                    local changed_files_err, changed_files = git.ls_changed()
                    scheduler()
                    if not changed_files_err then
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
                        if not hunks_err then
                            local files_err, lines = fs.read_file(filename)
                            if not files_err then
                                local data = calculate_diff(lines, hunks)
                                return nil,
                                    utils.readonly({
                                        changed_files = changed_files,
                                        diff_change = data,
                                        filetype = fs.detect_filetype(filename),
                                    })
                            else
                                logger.debug(files_err, 'init.lua/_rerender_project_diff')
                                return files_err,
                                    utils.readonly({
                                        changed_files = changed_files,
                                    })
                            end
                        else
                            logger.debug(hunks_err, 'init.lua/_rerender_project_diff')
                            return hunks_err, nil
                        end
                    else
                        logger.debug(changed_files_err, 'init.lua/_rerender_project_diff')
                        return changed_files_err, nil
                    end
                end, 0),
                selected_file
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M._keep_preview_focused = function()
    local preview = preview_store.get()
    if not vim.tbl_isempty(preview) and preview:is_mounted() then
        local win_ids = preview:get_win_ids()
        if #win_ids > 1 then
            local current_win_id = vim.api.nvim_get_current_win()
            if not vim.tbl_contains(win_ids, current_win_id) then
                local next_win_id = preview:get_next_win_id()
                vim.api.nvim_set_current_win(next_win_id)
            else
                preview:regenerate_win_toggle_queue()
            end
        end
    end
end

M.buffer_hunk_preview = throttle_leading(
    void(function(buf, win)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            if not controller_store.get('hunks_enabled') then
                return
            end
            local hunks = buffer_store.get(buf, 'hunks')
            if #hunks == 0 then
                logger.info('No changes found')
                return
            end
            local lnum = vim.api.nvim_win_get_cursor(win)[1]
            renderer.render_hunk_preview(
                wrap(function()
                    local read_file_err, lines = fs.read_file(buffer_store.get(buf, 'tracked_filename'))
                    scheduler()
                    if read_file_err then
                        logger.debug(read_file_err, 'init.lua/buffer_hunk_preview')
                        return read_file_err, nil
                    end
                    local data = diff.horizontal(lines, hunks)
                    return nil,
                        {
                            diff_change = data,
                            selected_hunk = get_current_hunk(hunks, lnum) or Hunk:new(),
                        }
                end, 0),
                buffer_store.get(buf, 'filetype')
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_gutter_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            renderer.render_gutter_blame_preview(
                wrap(function()
                    local filename = buffer_store.get(buf, 'tracked_filename')
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
                buffer_store.get(buf, 'filetype')
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M.hunk_down = void(function(buf, win)
    scheduler()
    buf = buf or buffer.current()
    if not controller_store.get('disabled') then
        local preview = preview_store.get()
        if not vim.tbl_isempty(preview) then
            if renderer.is_preview_navigatable(preview) then
                local marks = preview:get_marks()
                if preview:is_preview_focused() then
                    if #marks == 0 then
                        preview:notify('There are no changes')
                    else
                        local mark_index = navigation.mark_down(preview:get_preview_win_ids(), marks)
                        scheduler()
                        return preview:notify(string.format('%s/%s Changes', mark_index, #marks))
                    end
                end
            end
        end
        if buffer.is_valid(buf) and buffer_store.contains(buf) then
            win = win or vim.api.nvim_get_current_win()
            local hunks = buffer_store.get(buf, 'hunks')
            if #hunks ~= 0 then
                navigation.hunk_down({ win }, hunks)
                scheduler()
            end
        end
    end
end)

M.hunk_up = void(function(buf, win)
    scheduler()
    buf = buf or buffer.current()
    if not controller_store.get('disabled') then
        local preview = preview_store.get()
        if not vim.tbl_isempty(preview) then
            if renderer.is_preview_navigatable(preview) then
                local marks = preview:get_marks()
                if preview:is_preview_focused() then
                    if #marks == 0 then
                        preview:notify('There are no changes')
                    else
                        local mark_index = navigation.mark_up(preview:get_preview_win_ids(), marks)
                        scheduler()
                        return preview:notify(string.format('%s/%s Changes', mark_index, #marks))
                    end
                end
            end
        end
        if buffer.is_valid(buf) and buffer_store.contains(buf) then
            win = win or vim.api.nvim_get_current_win()
            local hunks = buffer_store.get(buf, 'hunks')
            if #hunks ~= 0 then
                navigation.hunk_up({ win }, hunks)
                scheduler()
            end
        end
    end
end)

M.buffer_hunk_reset = throttle_leading(
    void(function(buf, win)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            win = win or vim.api.nvim_get_current_win()
            local hunks = buffer_store.get(buf, 'hunks')
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
        end
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

M.project_diff_preview = throttle_leading(
    void(function()
        if not controller_store.get('disabled') then
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
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
                    if not hunks_err then
                        local files_err, lines = fs.read_file(filename)
                        if not files_err then
                            local data = calculate_diff(lines, hunks)
                            return nil,
                                utils.readonly({
                                    changed_files = changed_files,
                                    diff_change = data,
                                    filetype = fs.detect_filetype(filename),
                                })
                        else
                            logger.debug(files_err, 'init.lua/project_diff_preview')
                            return files_err,
                                utils.readonly({
                                    changed_files = changed_files,
                                })
                        end
                    else
                        logger.debug(hunks_err, 'init.lua/project_diff_preview')
                        return hunks_err, nil
                    end
                end, 0),
                diff_preference
            )
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
                buffer_store.for_each(function(buf, bcache)
                    if buffer.is_valid(buf) then
                        bcache:set('hunks', {})
                        renderer.hide_hunk_signs(buf)
                    end
                end)
                return controller_store.get('hunks_enabled')
            else
                controller_store.set('hunks_enabled', true)
            end
            buffer_store.for_each(function(buf, bcache)
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
        if not controller_store.get('disabled') then
            if controller_store.get('blames_enabled') then
                controller_store.set('blames_enabled', false)
                buffer_store.for_each(function(buf, bcache)
                    if buffer.is_valid(buf) then
                        detach_blames_autocmd(buf)
                        bcache:set('blames', {})
                        M._unblame_line(buf, true)
                    end
                end)
                return controller_store.get('blames_enabled')
            else
                controller_store.set('blames_enabled', true)
            end
            buffer_store.for_each(function(buf)
                if buffer.is_valid(buf) then
                    attach_blames_autocmd(buf)
                end
            end)
            return controller_store.get('blames_enabled')
        end
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

M.buffer_history_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
            renderer.render_history_preview(
                wrap(function()
                    local tracked_filename = buffer_store.get(buf, 'tracked_filename')
                    local logs_err, logs = git.logs(tracked_filename)
                    scheduler()
                    if not logs_err then
                        buffer_store.set(buf, 'logs', logs)
                        local temp_lines = buffer_store.get(buf, 'temp_lines')
                        if #temp_lines ~= 0 then
                            local lines = temp_lines
                            local hunks = buffer_store.get(buf, 'hunks')
                            local data = calculate_diff(lines, hunks)
                            return nil,
                                utils.readonly({
                                    logs = logs,
                                    diff_change = data,
                                })
                        else
                            local read_file_err, lines = fs.read_file(tracked_filename)
                            scheduler()
                            if not read_file_err then
                                local hunks_err, hunks = git.remote_hunks(tracked_filename, 'HEAD')
                                scheduler()
                                if hunks_err then
                                    logger.debug(hunks_err, 'init.lua/buffer_history_preview')
                                    return hunks_err, nil
                                end
                                local data = calculate_diff(lines, hunks)
                                return nil,
                                    utils.readonly({
                                        logs = logs,
                                        diff_change = data,
                                    })
                            else
                                logger.debug(read_file_err, 'init.lua/buffer_history_preview')
                                return read_file_err, nil
                            end
                        end
                    else
                        logger.debug(logs_err, 'init.lua/buffer_history_preview')
                        return logs_err, nil
                    end
                end, 0),
                buffer_store.get(buf, 'filetype'),
                diff_preference
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            if not controller_store.get('hunks_enabled') then
                return
            end
            local hunks = buffer_store.get(buf, 'hunks')
            if #hunks == 0 then
                logger.info('No changes found')
                return
            end
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
            renderer.render_diff_preview(
                wrap(function()
                    local tracked_filename = buffer_store.get(buf, 'tracked_filename')
                    if not hunks then
                        return { 'Failed to retrieve hunks for the current buffer' }, nil
                    end
                    local temp_lines = buffer_store.get(buf, 'temp_lines')
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
                    local data = calculate_diff(lines, hunks)
                    scheduler()
                    return nil, data
                end, 0),
                buffer_store.get(buf, 'filetype'),
                diff_preference
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_staged_diff_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
            and controller_store.get('diff_strategy') == 'index'
        then
            local diff_preference = controller_store.get('diff_preference')
            local calculate_diff = (diff_preference == 'horizontal' and diff.horizontal) or diff.vertical
            renderer.render_diff_preview(
                wrap(function()
                    local tracked_filename = buffer_store.get(buf, 'tracked_filename')
                    local hunks_err, hunks = git.staged_hunks(tracked_filename)
                    scheduler()
                    if hunks_err then
                        logger.debug(hunks_err, 'init.lua/buffer_staged_diff_preview')
                        return hunks_err, nil
                    end
                    scheduler()
                    local show_err, lines = git.show(buffer_store.get(buf, 'tracked_remote_filename'))
                    scheduler()
                    if show_err then
                        logger.debug(show_err, 'init.lua/buffer_staged_diff_preview')
                        return show_err, nil
                    end
                    local data = calculate_diff(lines, hunks)
                    scheduler()
                    return nil, data
                end, 0),
                buffer_store.get(buf, 'filetype'),
                diff_preference
            )
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_reset = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            local hunks = buffer_store.get(buf, 'hunks')
            if #hunks ~= 0 then
                local tracked_remote_filename = buffer_store.get(buf, 'tracked_remote_filename')
                if controller_store.get('diff_strategy') == 'remote' then
                    local err, lines = git.show(tracked_remote_filename, 'HEAD')
                    scheduler()
                    if not err then
                        buffer.set_lines(buf, lines)
                        vim.cmd('update')
                    else
                        logger.debug(err, 'init.lua/buffer_reset')
                    end
                else
                    local err, lines = git.show(tracked_remote_filename, '')
                    scheduler()
                    if not err then
                        buffer.set_lines(buf, lines)
                        vim.cmd('update')
                    else
                        logger.debug(err, 'init.lua/buffer_reset')
                    end
                end
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_blame_preview = throttle_leading(
    void(function(buf)
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer_store.get(buf, 'untracked')
        then
            local has_commits = git.has_commits()
            scheduler()
            if has_commits then
                local win = vim.api.nvim_get_current_win()
                local lnum = vim.api.nvim_win_get_cursor(win)[1]
                renderer.render_blame_preview(wrap(function()
                    local err, blame = git.blame_line(buffer_store.get(buf, 'tracked_filename'), lnum)
                    scheduler()
                    return err, blame
                end, 0))
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_hunk_stage = throttle_leading(
    void(function(buf, win)
        scheduler()
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer.get_option(buf, 'modified')
            and controller_store.get('diff_strategy') == 'index'
        then
            -- If buffer is untracked then, the whole file is the hunk.
            if buffer_store.get(buf, 'untracked') then
                local filename = buffer_store.get(buf, 'filename')
                local err = git.stage_file(filename)
                scheduler()
                if not err then
                    local tracked_filename = git.tracked_filename(filename)
                    scheduler()
                    local tracked_remote_filename = git.tracked_remote_filename(filename)
                    scheduler()
                    buffer_store.set(buf, 'tracked_filename', tracked_filename)
                    buffer_store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
                    buffer_store.set(buf, 'hunks', {})
                    buffer_store.set(buf, 'untracked', false)
                    renderer.hide_hunk_signs(buf)
                    renderer.render_hunk_signs(buf, {})
                else
                    logger.debug(err, 'init.lua/buffer_hunk_stage')
                end
                return
            end
            win = win or vim.api.nvim_get_current_win()
            local lnum = vim.api.nvim_win_get_cursor(win)[1]
            local hunks = buffer_store.get(buf, 'hunks')
            local selected_hunk = get_current_hunk(hunks, lnum)
            if selected_hunk then
                local tracked_filename = buffer_store.get(buf, 'tracked_filename')
                local tracked_remote_filename = buffer_store.get(buf, 'tracked_remote_filename')
                local patch = Patch:new(tracked_remote_filename, selected_hunk)
                local patch_filename = fs.tmpname()
                fs.write_file(patch_filename, patch)
                scheduler()
                local err = git.stage_hunk_from_patch(patch_filename)
                scheduler()
                fs.remove_file(patch_filename)
                scheduler()
                if not err then
                    local hunks_err, calculated_hunks = git.index_hunks(tracked_filename)
                    scheduler()
                    if not hunks_err then
                        buffer_store.set(buf, 'hunks', calculated_hunks)
                        renderer.hide_hunk_signs(buf)
                        renderer.render_hunk_signs(buf, calculated_hunks)
                    else
                        logger.debug(err, 'init.lua/buffer_hunk_stage')
                    end
                else
                    logger.debug(err, 'init.lua/buffer_hunk_stage')
                end
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_stage = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer.get_option(buf, 'modified')
            and controller_store.get('diff_strategy') == 'index'
        then
            local filename = buffer_store.get(buf, 'filename')
            local tracked_filename = buffer_store.get(buf, 'tracked_filename')
            local err = git.stage_file((tracked_filename and tracked_filename ~= '' and tracked_filename) or filename)
            scheduler()
            if not err then
                if buffer_store.get(buf, 'untracked') then
                    tracked_filename = git.tracked_filename(filename)
                    scheduler()
                    local tracked_remote_filename = git.tracked_remote_filename(filename)
                    scheduler()
                    buffer_store.set(buf, 'tracked_filename', tracked_filename)
                    buffer_store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
                    buffer_store.set(buf, 'untracked', false)
                end
                buffer_store.set(buf, 'hunks', {})
                renderer.hide_hunk_signs(buf)
                renderer.render_hunk_signs(buf, {})
            else
                logger.debug(err, 'init.lua/buffer_stage')
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

M.buffer_unstage = throttle_leading(
    void(function(buf)
        scheduler()
        buf = buf or buffer.current()
        if
            not controller_store.get('disabled')
            and buffer.is_valid(buf)
            and buffer_store.contains(buf)
            and not buffer.get_option(buf, 'modified')
            and controller_store.get('diff_strategy') == 'index'
            and not buffer_store.get(buf, 'untracked')
        then
            local filename = buffer_store.get(buf, 'filename')
            local tracked_filename = buffer_store.get(buf, 'tracked_filename')
            local err = git.unstage_file(tracked_filename)
            scheduler()
            if not err then
                tracked_filename = git.tracked_filename(filename)
                scheduler()
                local tracked_remote_filename = git.tracked_remote_filename(filename)
                scheduler()
                buffer_store.set(buf, 'tracked_filename', tracked_filename)
                buffer_store.set(buf, 'tracked_remote_filename', tracked_remote_filename)
                if tracked_filename and tracked_filename ~= '' then
                    buffer_store.set(buf, 'untracked', false)
                    local hunks_err, calculated_hunks = git.index_hunks(tracked_filename)
                    scheduler()
                    if not hunks_err then
                        buffer_store.set(buf, 'hunks', calculated_hunks)
                        renderer.hide_hunk_signs(buf)
                        renderer.render_hunk_signs(buf, calculated_hunks)
                    else
                        logger.debug(err, 'init.lua/buffer_unstage')
                    end
                else
                    buffer_store.set(buf, 'untracked', true)
                    local hunks = git.untracked_hunks(buffer.get_lines(buf))
                    scheduler()
                    buffer_store.set(buf, 'hunks', hunks)
                    renderer.hide_hunk_signs(buf)
                    renderer.render_hunk_signs(buf, hunks)
                end
            else
                logger.debug(err, 'init.lua/buffer_unstage')
            end
        end
    end),
    controller_store.get('action_delay_ms')
)

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
        else
            git.set_diff_base(diff_base)
            if controller_store.get('diff_strategy') == 'remote' then
                local data = buffer_store.get_data()
                for buf, bcache in pairs(data) do
                    local hunks_err, hunks = git.remote_hunks(bcache:get('tracked_filename'))
                    scheduler()
                    if not hunks_err then
                        bcache:set('hunks', hunks)
                        renderer.hide_hunk_signs(buf)
                        renderer.render_hunk_signs(buf, hunks)
                    else
                        logger.debug(hunks_err, 'init.lua/set_diff_base')
                    end
                end
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
        buffer_store.for_each(function(buf, bcache)
            if buffer.is_valid(buf) then
                local hunks_err, hunks = calculate_hunks(buf)
                scheduler()
                if not hunks_err then
                    controller_store.set('hunks_enabled', true)
                    bcache:set('hunks', hunks)
                    renderer.hide_hunk_signs(buf)
                    renderer.render_hunk_signs(buf, hunks)
                else
                    logger.debug(hunks_err, 'init.lua/set_diff_strategy')
                end
            end
        end)
    end),
    controller_store.get('action_delay_ms')
)

M.show_debug_logs = function()
    if logger.state:get('debug') then
        local debug_logs = logger.state:get('debug_logs')
        for i = 1, #debug_logs do
            local log = debug_logs[i]
            logger.error(log)
        end
    end
end

M.apply_highlights = function()
    highlight.setup(controller_store.get('config'), true)
end

-- Aliases
M.hunk_stage = M.buffer_hunk_stage
M.stage_buffer = M.buffer_stage
M.unstage_buffer = M.buffer_unstage
M.show_blame = M.buffer_show_blame
M.buffer_preview = M.buffer_diff_preview
M.staged_buffer_preview = M.buffer_staged_diff_preview
M.buffer_history = M.buffer_history_preview
M.diff = M.project_diff_preview
M.hunks_quickfix_list = M.project_hunks_qf
M.hunk_reset = M.buffer_hunk_reset
M.hunk_preview = M.buffer_hunk_preview
M.buffer_hunk_lens = M.buffer_hunk_preview

-- Submodules
M.renderer = renderer
M.events = events
M.highlight = highlight
M.themes = themes
M.layouts = layouts
M.dimensions = dimensions

M.setup = function(config)
    controller_store.setup(config)
    render_store.setup(config)
    events.setup()
    highlight.setup(config)
    sign.setup(config)
    logger.setup(config)
    git.setup(config)
    key_mapper.setup(config)
    events.on('BufWinEnter', ':lua require("vgit")._buf_attach()')
    events.on('WinEnter', ':lua require("vgit")._keep_preview_focused()')
    events.on('BufWrite', ':lua require("vgit")._buf_update()')
    vim.cmd(
        string.format(
            'com! -nargs=+ %s %s',
            '-complete=customlist,v:lua.package.loaded.vgit._command_autocompletes',
            'VGit lua require("vgit")._run_command(<f-args>)'
        )
    )
end

return M
