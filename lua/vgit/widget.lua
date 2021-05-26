local buffer = require('vgit.buffer')
local vim = vim

local M = {}

M.create = function(options)
    local all_wins = {}
    for _, v in pairs(options.views) do
        table.insert(all_wins, v.win_id)
        if v.border_win_id then
            table.insert(all_wins, v.border_win_id)
        end
        if v.border_buf then
            table.insert(all_wins, v.border_win_id)
        end
    end
    for _, v in pairs(options.views) do
        buffer.add_autocmd(
            v.buf,
            'BufWinLeave',
            string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
        )
        if v.actions then
            for _, action in ipairs(v.actions) do
                buffer.add_keymap(
                    v.buf,
                    action.mapping,
                    (type(action.action) == 'function' and action.action(options)) or action.action
                )
            end
        end
    end
    for _, mapping in ipairs(options.close_mappings) do
        for _, v in pairs(options.views) do
            buffer.add_keymap(
                v.buf,
                mapping,
                string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
            )
        end
    end
    local bufs = vim.api.nvim_list_bufs()
    for _, buf in ipairs(bufs) do
        local is_buf_listed = vim.api.nvim_buf_get_option(buf, 'buflisted') == true
        if is_buf_listed then
            if vim.api.nvim_buf_is_loaded(buf) then
                buffer.add_autocmd(
                    buf,
                    'BufEnter',
                    string.format('_run_submodule_command("ui", "close_windows", %s)', vim.inspect(all_wins))
                )
            end
        end
    end
    return options
end

return M
