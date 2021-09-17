local git = require('vgit.git')
local highlight = require('vgit.highlight')
local renderer = require('vgit.renderer')
local fs = require('vgit.fs')
local preview_store = require('vgit.stores.preview_store')
local buffer = require('vgit.buffer')
local throttle_leading = require('vgit.defer').throttle_leading
local controller_store = require('vgit.stores.controller_store')
local logger = require('vgit.logger')
local navigation = require('vgit.navigation')
local Patch = require('vgit.Patch')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local controller_utils = require('vgit.controller_utils')

local M = {}

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
        local selected_hunk = controller_utils.get_current_hunk(hunks, lnum)
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
                    local hunks_err, hunks = controller_utils.calculate_hunks(buf)
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
                    controller_utils.detach_blames_autocmd(buf)
                    bcache:set('blames', {})
                    M._unblame_line(buf, true)
                end
            end)
            return controller_store.get('blames_enabled')
        end
        controller_store.set('blames_enabled', true)
        buffer.store.for_each(function(buf)
            if buffer.is_valid(buf) then
                controller_utils.attach_blames_autocmd(buf)
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

return M
