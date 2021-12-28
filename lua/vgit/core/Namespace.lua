local signs_setting = require('vgit.settings.signs')
local Object = require('vgit.core.Object')

local Namespace = Object:extend()

function Namespace:new()
  return setmetatable({
    ns_id = vim.api.nvim_create_namespace(''),
  }, Namespace)
end

function Namespace:sign_ns_id(buffer)
  return string.format('tanvirtin/vgit.nvim/hunk/signs/%s', buffer.bufnr)
end

function Namespace:add_highlight(buffer, hl, row, col_start, col_end)
  vim.api.nvim_buf_add_highlight(
    buffer.bufnr,
    self.ns_id,
    hl,
    row,
    col_start,
    col_end
  )
  return self
end

function Namespace:transpose_virtual_text(buffer, text, hl, row, col, pos)
  pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, col, {
    id = row + 1 + col,
    virt_text = { { text, hl } },
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
  })
  return self
end

function Namespace:transpose_virtual_line(buffer, texts, col, pos)
  pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, col, 0, {
    id = col + 1,
    virt_text = texts,
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
  })
  return self
end

function Namespace:sign_place(buffer, lnum, sign_definition)
  vim.fn.sign_place(lnum, self:sign_ns_id(buffer), sign_definition, buffer.bufnr, {
    id = lnum,
    lnum = lnum,
    priority = signs_setting:get('priority'),
  })
  return self
end

function Namespace:sign_unplace(buffer)
  vim.fn.sign_unplace(self:sign_ns_id(buffer))
  return self
end

function Namespace:clear(buffer)
  vim.api.nvim_buf_clear_namespace(buffer.bufnr, self.ns_id, 0, -1)
  return self
end

return Namespace
