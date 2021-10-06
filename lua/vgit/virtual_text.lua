local M = {}

M.add = vim.api.nvim_buf_set_extmark

M.delete = vim.api.nvim_buf_del_extmark

M.transpose_text = function(buf, text, ns_id, hl_group, row, col_start, pos)
  vim.api.nvim_buf_set_extmark(buf, ns_id, row, col_start, {
    id = row + 1 + col_start,
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

M.clear = function(buf, ns_id)
  vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
end

return M
