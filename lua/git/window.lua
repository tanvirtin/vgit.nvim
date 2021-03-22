local window = {}

window.popup = function(content, opts)
    local bufnr = vim.api.nvim_create_buf(false, true)
    assert(bufnr, "Failed to create buffer")

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, content)

    local width
    if opts.width then
        width = opts.width
    else
        width = 0
        for _, line in ipairs(content) do
            local line_width = #line + 6
            if line_width > width then
                width = line_width
            end
        end
    end

    if width < 10 then
        width = 25
    end

    opts = opts or {}

    local win_id = vim.api.nvim_open_win(bufnr, false, {
        relative = opts.relative,
        row = opts.row or 0,
        col = opts.col or 0,
        height = opts.height or #content,
        width = width,
    })

    vim.lsp.util.close_preview_autocmd({ 'CursorMoved', 'CursorMovedI' }, win_id)

    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')
    vim.api.nvim_win_set_option(win_id, 'number', false)
    vim.api.nvim_win_set_option(win_id, 'relativenumber', false)

    return win_id, bufnr
end

return window
