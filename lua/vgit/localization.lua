-- luacheck: max line length 300

local State = require('vgit.State')

local vim = vim

local M = {}

-- Any string put here is for the end user.
M.state = State.new({
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
        buf_attach_hunks = 'VGit: Failed to compute hunks for the file "%s", when attaching buffer',
        blame_line = 'VGit: Failed to blame line for the file "%s"',
        invalid_command = 'VGit: Invalid command',
        invalid_submodule_command = 'VGit: Invalid submodule command',
        change_history_hunks = 'VGit: Failed to retrieve hunks from origin when changing history for the following hashes, parent: "%s", commit: "%s"',
        change_history_show = 'VGit: Failed to retrieve buffer from origin when changing history',
        change_history_diff = 'VGit: Failed to compute diff when changing history',
        quickfix_list_hunks = 'VGit: Failed to compute hunks when showing quickfix list of hunks',
        toggle_buffer_hunks = 'VGit: Failed to retrieve hunks on toggle for the file "%s"',
        toggle_buffer_blames = 'VGit: Failed to retrieve line blame on toggle for the file "%s"',
        buffer_history_logs = 'VGit: Failed to retrieve logs for the file "%s", when showing buffer history',
        buffer_history_file = 'VGit: Failed to read file "%s", when showing buffer history',
        buffer_history_diff = 'VGit: Failed to compute diff for the file "%s", when showing buffer history',
        buffer_preview_diff = 'VGit: Failed to compute diff for the file, "%s", when showing buffer preview',
        buffer_reset = 'VGit: Failed to reset buffer for the file, "%s"',
        setup_tracked_file = 'VGit: Failed to retrieve tracked files for the project',
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
