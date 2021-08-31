local M = {}

M.add = vim.api.nvim_buf_set_extmark

M.delete = vim.api.nvim_buf_del_extmark

M.transpose_text = function(buf, text, ns_id, hl_group, lnum, col_start, pos)
    vim.api.nvim_buf_set_extmark(buf, ns_id, lnum, col_start, {
        id = lnum + 1,
        virt_text = { { text, hl_group } },
        virt_text_pos = pos or 'overlay',
        hl_mode = 'combine',
    })
end

M.transpose_line = function(buf, texts, ns_id, lnum, pos)
    vim.api.nvim_buf_set_extmark(buf, ns_id, lnum, 0, {
        id = lnum + 1,
        virt_text = texts,
        virt_text_pos = pos or 'overlay',
        hl_mode = 'combine',
    })
end

return M
