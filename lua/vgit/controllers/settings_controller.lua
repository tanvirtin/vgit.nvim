local git = require('vgit.git')
local renderer = require('vgit.renderer')
local buffer = require('vgit.buffer')
local throttle_leading = require('vgit.defer').throttle_leading
local controller_store = require('vgit.stores.controller_store')
local logger = require('vgit.logger')
local void = require('plenary.async.async').void
local scheduler = require('plenary.async.util').scheduler
local controller_utils = require('vgit.controller_utils')

local M = {}

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
                local hunks_err, hunks = controller_utils.calculate_hunks(buf)
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

return M
