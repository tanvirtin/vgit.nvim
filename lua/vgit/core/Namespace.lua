local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')
local signs_setting = require('vgit.settings.signs')

local Namespace = Object:extend()

function Namespace:constructor(name)
  name = name or utils.math.uuid()

  return {
    virtual_line_number_id = math.pow(24, 5),
    inserted_virtual_line_id = math.pow(25, 5),
    ns_id = vim.api.nvim_create_namespace(name),
  }
end

function Namespace:get_sign_ns_id(buffer)
  return string.format('tanvirtin/vgit.nvim/hunk/signs/%s', buffer.bufnr)
end

function Namespace:add_highlight(buffer, opts)
  local hl = opts.hl
  local row = opts.row
  local col_range = opts.col_range

  return pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, col_range.from, {
    end_col = col_range.to,
    hl_group = hl,
  })
end

function Namespace:add_pattern_highlight(buffer, pattern, hl)
  local result = {}

  local lines = buffer:get_lines()
  for i = 1, #lines do
    local line = lines[i]

    local j = 0
    while true do
      local from, to = line:find(pattern, j + 1)
      if from == nil then break end

      local ok, value = self:add_highlight(buffer, {
        hl = hl,
        row = i - 1,
        col_range = {
          from = from - 1,
          to = to,
        },
      })
      if not ok then return false, value end

      j = from
      result[#result + 1] = value
    end
  end

  return true, result
end

function Namespace:transpose_virtual_text(buffer, opts)
  local text = opts.text
  local hl = opts.hl
  local row = opts.row
  local col = opts.col
  local pos = opts.pos
  local priority = opts.priority

  local id = row + 1 + col

  return pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, col, {
    id = id,
    virt_text = { { text, hl } },
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
    priority = priority,
  })
end

function Namespace:transpose_virtual_line(buffer, opts)
  local texts = opts.texts
  local row = opts.row
  local pos = opts.pos
  local priority = opts.priority

  local id = row + 1

  return pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_text = texts,
    virt_text_pos = pos or 'overlay',
    hl_mode = 'combine',
    priority = priority,
  })
end

function Namespace:transpose_virtual_line_number(buffer, opts)
  local row = opts.row
  local hl = opts.hl
  local text = opts.text
  local id = self.virtual_line_number_id + row + 1

  return pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_text = { { text, hl } },
    virt_text_pos = 'inline',
    hl_mode = 'combine',
  })
end

function Namespace:insert_virtual_line(buffer, opts)
  local row = opts.row
  local hl = opts.hl
  local text = opts.text
  local priority = opts.priority

  local id = self.virtual_line_number_id + row + 1

  return pcall(vim.api.nvim_buf_set_extmark, buffer.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_lines = { { { text, hl } } },
    virt_lines_above = true,
    priority = priority,
  })
end

function Namespace:sign_place(buffer, lnum, sign_name)
  return pcall(vim.fn.sign_place, lnum, self:get_sign_ns_id(buffer), sign_name, buffer.bufnr, {
    id = lnum,
    lnum = lnum,
    buffer = buffer.bufnr,
    priority = signs_setting:get('priority'),
  })
end

function Namespace:sign_unplace(buffer, lnum)
  return pcall(vim.fn.sign_unplace, self:get_sign_ns_id(buffer), { buffer = buffer.bufnr, id = lnum })
end

function Namespace:clear(buffer, row_range)
  row_range = row_range or {}
  local row_from = row_range.from or 0
  local row_to = row_range.to or -1

  return pcall(vim.api.nvim_buf_clear_namespace, buffer.bufnr, self.ns_id, row_from, row_to)
end

return Namespace
