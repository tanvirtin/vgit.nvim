local assert = require('vgit.assertion').assert
local State = require('vgit.State')

local vim = vim

local M = {}

M.state = State.new({
    preview = {
        horizontal = 'Preview',
        current = 'Current',
        previous = 'Previous',
    },
    history = {
        horizontal = 'Preview',
        history = 'Git History',
        current = 'Current',
        previous = 'Previous',
        no_commits = 'No commits to show',
    },
    errors = {
        invalid_command = 'Invalid command "%s"',
        set_diff_base = 'Failed to set diff base, the commit "%s" is invalid',
        set_diff_preference = 'Failed to set diff preferece, "%s" is invalid',
        set_diff_strategy = 'Failed to set diff strategy, "%s" is invalid',
        set_hunk_prediction_strategy = 'Failed to set hunk prediction type, "%s" is invalid',
    },
})

M.setup = function(config)
    M.state:assign(config)
end

M.translate = function(key, ...)
    assert(type(key) == 'string', 'type error :: expected string')
    local sep = '/'
    local key_fragments = vim.split(key, sep)
    local translation = nil
    for i = 1, #key_fragments do
        local frag = key_fragments[i]
        if i == 1 then
            translation = M.state:get(frag)
        else
            translation = translation[frag]
            assert(type(translation) == 'string', 'type error :: expected string')
        end
    end
    return string.format(translation, ...)
end

return M
