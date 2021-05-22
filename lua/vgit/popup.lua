local M = {}

local vim = vim

M.highlight_with_ts = function(buf, ft)
    local has_ts = false
    local ts_highlight = nil
    local ts_parsers = nil
    if not has_ts then
        has_ts, _ = pcall(require, 'nvim-treesitter')
        if has_ts then
            _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
            _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')
        end
    end
    if has_ts and ft and ft ~= '' then
        local lang = ts_parsers.ft_to_lang(ft);
        if ts_parsers.has_parser(lang) then
            ts_highlight.attach(buf, lang)
            return true
        end
    end
    return false
end

M.create = function(options)
    local buf = vim.api.nvim_create_buf(false, true)
    if options.lines then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, options.lines)
    end
    if options.filetype then
        M.highlight_with_ts(buf, options.filetype)
    end
    if options.buf_options then
        for key, value in pairs(options.buf_options) do
            vim.api.nvim_buf_set_option(buf, key, value)
        end
    end
    local win_id = vim.api.nvim_open_win(buf, true, options.window_props)
    if options.win_options then
        for key, value in pairs(options.win_options) do
            vim.api.nvim_win_set_option(win_id, key, value)
        end
    end
    options.buf = buf
    options.win_id = win_id
    return options
end

M.add_keymap = function(buf, key, action)
    vim.api.nvim_buf_set_keymap(buf, 'n', key, string.format(':lua require("vgit").%s<CR>', action), {
        silent = true,
        noremap = true
    })
end

M.add_autocmd = function(buf, cmd, action)
    vim.api.nvim_command(
        string.format(
            'autocmd %s <buffer=%s> lua require("vgit").%s',
            cmd,
            buf,
            action
        )
    )
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

M.close = function(wins)
    if type(wins) == 'table' then
        for _, win in ipairs(wins) do
            if vim.api.nvim_win_is_valid(win) then
                vim.api.nvim_win_close(win, true)
            end
        end
    end
end

M.close_mappings = function(mappings, windows)
    local all_wins = {}
    for _, window in pairs(windows) do
        table.insert(all_wins, window.win_id)
    end
    for _, mapping in ipairs(mappings) do
        for _, window in pairs(windows) do
            M.add_keymap(
                window.buf,
                mapping,
                string.format('_run_submodule_command("popup", "close", %s)', vim.inspect(all_wins))
            )
        end
    end
end

M.connect_closing_windows = function(windows)
    local all_wins = {}
    for _, window in pairs(windows) do
        table.insert(all_wins, window.win_id)
    end
    for _, window in pairs(windows) do
        M.add_autocmd(
            window.buf,
            'BufWinLeave',
            string.format('_run_submodule_command("popup", "close", %s)', vim.inspect(all_wins))
        )
    end
end

return M
