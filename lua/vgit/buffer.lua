local M = {}

local vim = vim

M.current = function()
    return vim.api.nvim_get_current_buf()
end

M.add_autocmd = function(buf, cmd, action, options)
    local persist = (options and options.persist) or false
    local override = (options and options.override) or false
    local nested = (options and options.nested) or true
    vim.cmd(
        string.format(
            'au%s %s <buffer=%s> %s %s :lua require("vgit").%s',
            override and '!' or '',
            cmd,
            buf,
            nested and '++nested' or '',
            persist and '' or '++once',
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

M.is_valid = function(buf)
    return vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf)
end

return M
