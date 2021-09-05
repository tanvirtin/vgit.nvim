local M = {
    buf = {},
    namespace = 'tanvirtin/vgit',
}

M.setup = function()
    vim.cmd(string.format('aug %s | autocmd! | aug END', M.namespace))
end

M.off = function(key)
    vim.cmd(string.format('aug %s/%s | autocmd! | aug END', M.namespace, key))
end

M.on = function(cmd, handler, options)
    local once = (options and options.once) or false
    local override = (options and options.override) or false
    local nested = (options and options.nested) or false
    local key = (options and string.format('%s/%s', M.namespace, options.key)) or ''
    if key ~= '' then
        vim.cmd(string.format('aug %s | autocmd! | aug END', key))
    end
    vim.api.nvim_exec(
        string.format(
            'au%s %s %s %s * %s %s %s',
            override and '!' or '',
            key,
            M.namespace,
            cmd,
            nested and '++nested' or '',
            once and '++once' or '',
            handler
        ),
        false
    )
end

M.buf.on = function(buf, cmd, handler, options)
    local once = (options and options.once) or false
    local override = (options and options.override) or false
    local nested = (options and options.nested) or false
    -- NOTE: This introduces a constraint -- a single buf can never register more than one action for a single cmd
    local key = (options and options.key and options.key ~= '' and string.format('%s/%s', M.namespace, options.key))
        or string.format('%s/%s/%s', M.namespace, buf, cmd)
    vim.cmd(string.format('aug %s | autocmd! | aug END', key))
    vim.api.nvim_exec(
        string.format(
            'au%s %s %s <buffer=%s> %s %s %s',
            override and '!' or '',
            key,
            cmd,
            buf,
            nested and '++nested' or '',
            once and '++once' or '',
            handler
        ),
        false
    )
end

return M
