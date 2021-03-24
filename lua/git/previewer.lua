local M = {}

local state = {
    hunk = {
        add = {
            hl = 'GitHunkAdd',
            color = '#d7ffaf',
        },
        remove = {
            hl = 'GitHunkRemove',
            color = '#e95678',
        },
    }
}

local function pad_content(padding, content)
    pad_top = padding[1] or 0
    pad_right = padding[2] or 0
    pad_below = padding[3] or 0
    pad_left = padding[4] or 0

    local left_padding = string.rep(' ', pad_left)
    local right_padding = string.rep(' ', pad_right)
    for index = 1, #content do
        content[index] = left_padding .. content[index] .. right_padding
    end

    for _ = 1, pad_top do
        table.insert(content, 1, '')
    end

    for _ = 1, pad_below do
        table.insert(content, '')
    end

    return content
end

-- TODO configure state here
M.initialize = function()
end

M.tear_down = function()
    state = nil
end

M.show_hunk = function(hunk)
    local content = hunk.diff
    local min_width = 25
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, pad_content({ 1, 0, 1, 2 }, content))

    local width = min_width
    for _, line in ipairs(content) do
        local line_width = #line + 5
        if line_width > width then
            width = line_width
        end
    end

    local win_id = vim.api.nvim_open_win(bufnr, false, {
        relative = 'cursor',
        row = 0,
        col = 0,
        height = #content,
        width = width,
    })

    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')
    vim.api.nvim_win_set_option(win_id, 'number', false)
    vim.api.nvim_win_set_option(win_id, 'relativenumber', false)

    -- Auto close buffer when cursor is moved.
    vim.lsp.util.close_preview_autocmd({ 'CursorMoved', 'CursorMovedI' }, win_id)

    return win_id, bufnr
end

return M
