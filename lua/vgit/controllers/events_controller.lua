local preview_store = require('vgit.stores.preview_store')
local git = require('vgit.git')
local renderer = require('vgit.renderer')
local fs = require('vgit.fs')
local buffer = require('vgit.buffer')
local controller_store = require('vgit.stores.controller_store')
local debounce_trailing = require('vgit.defer').debounce_trailing
local logger = require('vgit.logger')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local controller_utils = require('vgit.controller_utils')
local Hunk = require('vgit.Hunk')

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
        int_hunk_generation(buf, original_lines, current_lines)
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
        controller_utils.attach_blames_autocmd(buf)
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
    local err, hunks = controller_utils.calculate_hunks(buf)
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

local M = {}

M._buf_attach = void(function(buf)
    scheduler()
    buf = buf or buffer.current()
    if not buffer.is_valid(buf) then
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
        controller_utils.store_buf(buf, filename, tracked_filename, tracked_remote_filename)
        return buf_attach_tracked(buf)
    end
    if controller_store.get('diff_strategy') == 'index' and controller_store.get('show_untracked_file_signs') then
        local is_ignored = git.check_ignored(filename)
        scheduler()
        if not is_ignored then
            controller_utils.store_buf(buf, filename, tracked_filename, tracked_remote_filename)
            buf_attach_untracked(buf)
        end
    end
end)

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
        local err, hunks = controller_utils.calculate_hunks(buf)
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
    controller_utils.detach_blames_autocmd(buf)
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

return M
