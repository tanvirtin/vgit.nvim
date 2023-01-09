local Object = require('vgit.core.Object')
local signs_setting = require('vgit.settings.signs')

local Namespace = Object:extend()

function Namespace:constructor(name)
  return {
    ns_id = vim.api.nvim_create_namespace(name or ''),
  }
end

function Namespace:get_sign_ns_id(buffer) return string.format('tanvirtin/vgit.nvim/hunk/signs/%s', buffer.bufnr) end

function Namespace:add_highlight(buffer, hl, row, col_start, col_end)
  pcall(vim.api.nvim_buf_add_highlight, buffer.bufnr, self.ns_id, hl, row, col_start, col_end)

  return self
end

function Namespace:add_pattern_highlight(buffer, pattern, hl)
  local lines = buffer:get_lines()

  for i = 1, #lines do
    local line = lines[i]

    local j = 0

    while true do
      local from, to = line:find(pattern, j + 1)

      j = from

      if from == nil then
        break
      end

      self:add_highlight(buffer, hl, i - 1, from - 1, to)
    end
  end

  return self
end

function Namespace:transpose_virtual_text(buffer, text, hl, row, col, pos, priority)
  local id = row + 1 + col

  pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, col, {
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

  pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, 0, {
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

  pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_lines = lines,
    virt_lines_above = true,
    priority = priority,
  })

  return id
end

function Namespace:sign_place(buffer, lnum, sign_name)
  pcall(vim.fn.sign_place, lnum, self:get_sign_ns_id(buffer), sign_name, buffer.bufnr, {
    id = lnum,
    lnum = lnum,
    buffer = buffer.bufnr,
    priority = signs_setting:get('priority'),
  })

  return self
end

function Namespace:sign_unplace(buffer, lnum)
  pcall(vim.fn.sign_unplace, self:get_sign_ns_id(buffer), { buffer = buffer.bufnr, id = lnum })

  return self
end

function Namespace:clear(buffer, row_start, row_end)
  row_start = row_start or 0
  row_end = row_end or -1

  pcall(vim.api.nvim_buf_clear_namespace, buffer.bufnr, self.ns_id, row_start, row_end)

  return self
end

function Namespace:clear_extmark(buffer, id)
  pcall(vim.api.nvim_buf_del_extmark, buffer.bufnr, self.ns_id, id)

  return self
end

return Namespace
