local vim = vim

local M = {}

local function create_lines(title, content_win_options, border)
    local border_lines = {}
    local topline = nil
    if content_win_options.row > 0 then
        if title ~= '' then
            title = string.format(" %s ", title)
        end
        local title_len = string.len(title)
        local midpoint = math.floor(content_win_options.width / 2)
        local left_start = midpoint - math.floor(title_len / 2)
        topline = string.format(
            "%s%s%s%s%s",
            border[1],
            string.rep(border[2], left_start),
            title,
            string.rep(border[2], content_win_options.width - title_len - left_start),
            border[3]
        )
    end
    if topline then
        table.insert(border_lines, topline)
    end
    local middle_line = string.format(
        "%s%s%s",
        border[4] or '',
        string.rep(' ', content_win_options.width),
        border[8] or ''
    )
    for _ = 1, content_win_options.height do
        table.insert(border_lines, middle_line)
    end
    table.insert(border_lines, string.format(
        "%s%s%s",
        border[7] or '',
        string.rep(border[6], content_win_options.width),
        border[5] or ''
    ))
    return border_lines
end

M.create = function(title, content_bufnr, content_win_id, content_win_options, border)
    local obj = {}
    local thickness = {
        top = 1,
        right = 1,
        bot = 1,
        left = 1,
    }
    obj.bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(obj.bufnr, "bufhidden", "wipe")
    vim.api.nvim_buf_set_lines(obj.bufnr, 0, -1, false, create_lines(title, content_win_options, border))
    obj.win_id = vim.api.nvim_open_win(obj.bufnr, false, {
        relative = 'editor',
        style = "minimal",
        row = content_win_options.row - thickness.top,
        col = content_win_options.col - thickness.left,
        width = content_win_options.width + thickness.left + thickness.right,
        height = content_win_options.height + thickness.top + thickness.bot,
        focusable = false,
    })
    vim.api.nvim_win_set_option(obj.win_id, 'cursorbind', false)
    vim.api.nvim_win_set_option(obj.win_id, 'scrollbind', false)
    vim.cmd(
        string.format(
            "autocmd BufDelete <buffer=%s> ++nested ++once :lua require('plenary.window').close_related_win(%s, %s)",
            content_bufnr,
            content_win_id,
            obj.win_id
        )
    )
    vim.cmd(
        string.format(
            "autocmd WinClosed <buffer=%s> ++nested ++once :lua require('plenary.window').try_close(%s, true)",
            content_bufnr,
            obj.win_id
        )
    )
    return obj
end

return M
