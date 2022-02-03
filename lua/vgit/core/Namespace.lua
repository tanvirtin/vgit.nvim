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

function Namespace:transpose_virtual_text(
  buffer,
  text,
  hl,
  row,
  col,
  pos,
  priority
)
  local id = row + 1 + col
  vim.api.nvim_buf_set_extmark(buffer.bufnr, self.ns_id, row, col, {
    id = id,
    virt_text = { { text, hl } },
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
    priority = priority,
  })
  return id
end

function Namespace:transpose_virtual_line(buffer, texts, row, pos, priority)
  local id = row + 1
  vim.api.nvim_buf_set_extmark(buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_text = texts,
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
    priority = priority,
  })
  return id
end

function Namespace:insert_virtual_lines(buffer, lines, row, priority)
  local id = row + 1
  vim.api.nvim_buf_set_extmark(buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_lines = lines,
    virt_lines_above = true,
    priority = priority,
  })
  return id
end

function Namespace:sign_place(buffer, lnum, sign_name)
  vim.fn.sign_place(lnum, self:sign_ns_id(buffer), sign_name, buffer.bufnr, {
    id = lnum,
    lnum = lnum,
    buffer = buffer.bufnr,
    priority = signs_setting:get('priority'),
  })
  return self
end

function Namespace:sign_unplace(buffer, lnum)
  vim.fn.sign_unplace(
    self:sign_ns_id(buffer),
    { buffer = buffer.bufnr, id = lnum }
  )
  return self
end

function Namespace:clear(buffer)
  vim.api.nvim_buf_clear_namespace(buffer.bufnr, self.ns_id, 0, -1)
  return self
end

function Namespace:clear_extmark(buffer, id)
  vim.api.nvim_buf_del_extmark(buffer.bufnr, self.ns_id, id)
  return self
end

return Namespace
