local M = {}

local vim = vim

M.add_autocmd = function(buf, cmd, action)
    vim.api.nvim_command(
        string.format(
            'autocmd %s <buffer=%s> ++nested ++once :lua require("vgit").%s',
            cmd,
            buf,
            action
        )
    )
end

M.add_keymap = function(buf, key, action)
    vim.api.nvim_buf_set_keymap(buf, 'n', key, string.format(':lua require("vgit").%s<CR>', action), {
        silent = true,
        noremap = true
    })
end

M.get_lines = function(buf, start, finish)
    start = start or 0
    finish = finish or -1
    return vim.api.nvim_buf_get_lines(buf, start, finish, false)
end

M.set_lines = function(buf, lines)
    local modifiable = vim.api.nvim_buf_get_option(buf, 'modifiable')
    if not modifiable then
        vim.api.nvim_buf_set_option(buf, 'modifiable', true)
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
    else
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    end
end

M.assign_options = function(buf, options)
    for key, value in pairs(options) do
        vim.api.nvim_buf_set_option(buf, key, value)
    end
end

return M
