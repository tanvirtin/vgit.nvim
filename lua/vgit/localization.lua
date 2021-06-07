-- luacheck: max line length 300

local State = require('vgit.State')

local vim = vim

local M = {}

-- Any string put here is for the end user.
M.state = State.new({
    loading = 'Loading...',
    error = 'An error has occured',
    preview = {
        current = 'Current',
        previous = 'Previous',
    },
    history = {
        history = 'Git History',
        current = 'Current',
        previous = 'Previous',
    },
    errors = {
        compute_hunks = 'VGit: Failed to compute hunks for the file "%s"',
        blame_line = 'VGit: Failed to blame line for the file "%s"',
        invalid_command = 'VGit: Invalid command',
        invalid_submodule_command = 'VGit: Invalid submodule command',
        quickfix_list_hunks = 'VGit: Failed to compute hunks when showing quickfix list of hunks',
        toggle_buffer_hunks = 'VGit: Failed to retrieve hunks on toggle for the file "%s"',
        toggle_buffer_blames = 'VGit: Failed to retrieve line blame on toggle for the file "%s"',
        buffer_reset = 'VGit: Failed to reset buffer for the file, "%s"',
        setup_tracked_file = 'VGit: Failed to retrieve tracked files for the project',
        set_diff_base = 'VGit: Failed to set diff base, the commit "%s" is invalid'
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
            assert(type(translation) == 'string', 'Invalid translation string')
        end
    end
    return string.format(translation, ...)
end

return M
