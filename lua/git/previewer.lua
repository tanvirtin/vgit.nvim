local highlight = require('git.highlight')

local M = {}

local state = {
    hunk = {
        add = {
            hl = 'GitHunkAdd',
            bg = nil,
            fg = '#d7ffaf',
        },
        remove = {
            hl = 'GitHunkRemove',
            bg = nil,
            fg = '#e95678',
        },
    }
}

local function pad_content(content, padding)
    pad_top = padding[1] or 0
    pad_right = padding[2] or 0
    pad_below = padding[3] or 0
    pad_left = padding[4] or 0

    local left_padding = string.rep(' ', pad_left)
    local right_padding = string.rep(' ', pad_right)
    for index = 1, #content do
        local line = content[index]
        if line ~= '' then
            content[index] = left_padding .. line .. right_padding
        end
    end

    for _ = 1, pad_top do
        table.insert(content, 1, '')
    end

    for _ = 1, pad_below do
        table.insert(content, '')
    end

    return content
end

M.initialize = function()
    for _, action in pairs(state.hunk) do
        highlight.add(action.hl, action);
    end
end

M.tear_down = function()
    state = nil
end

M.show_hunk = function(hunk)
    local padding = { 1, 3, 1, 3 }
    local content = pad_content(vim.deepcopy(hunk.diff), padding)
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, content)
    vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'wipe')
    vim.api.nvim_buf_set_option(bufnr, 'filetype', 'diff')

    for index, line in pairs(content) do
        -- Trim the string removing empty spaces.
        line = line:gsub('%s+', '')
        local first_letter = line:sub(1, 1)
        if first_letter == '+' then
            vim.api.nvim_buf_add_highlight(bufnr, -1, state.hunk.add.hl, index - 1, 0, -1)
        elseif first_letter == '-' then
            vim.api.nvim_buf_add_highlight(bufnr, -1, state.hunk.remove.hl, index - 1, 0, -1)
        end
    end

    local width = 25
    local height = #content
    for _, line in ipairs(content) do
        local line_width = #line
        if line_width > width then
            width = line_width
        end
    end

    local win_id = vim.api.nvim_open_win(bufnr, false, {
        relative = 'cursor',
        style = 'minimal',
        height = height,
        width = width,
        row = 0,
        col = 0,
    })

    vim.lsp.util.close_preview_autocmd({ 'BufLeave', 'CursorMoved', 'CursorMovedI' }, win_id)
end

return M
