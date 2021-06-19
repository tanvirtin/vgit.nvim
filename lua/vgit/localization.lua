local State = require('vgit.State')

local vim = vim

local M = {}

M.state = State.new({
    loading = 'Loading...',
    error = 'An error has occured',
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
    }
})

M.setup = function(config)
    M.state:assign(config)
end

M.translate = function(key, ...)
    local sep = '/'
    local key_fragments = vim.split(key, sep)
    local translation = nil
    for index, frag in ipairs(key_fragments) do
        if index == 1 then
           translation = M.state:get(frag)
        else
            translation = translation[frag]
            assert(type(translation) == 'string', 'type error :: expected string')
        end
    end
    return string.format(translation, ...)
end

return M
