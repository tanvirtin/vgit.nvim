local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local signs_setting = lazy('vgit.settings.signs')

-- Cache sign settings at module level — these never change after setup
local _sign_priority
local _sign_definitions

local function get_sign_priority()
  if not _sign_priority then _sign_priority = signs_setting:get('priority') end
  return _sign_priority
end

local function get_sign_definition(name)
  if not _sign_definitions then _sign_definitions = signs_setting:get('definitions') end
  return _sign_definitions[name]
end

local Extmark = Object:extend()

function Extmark:constructor(bufnr, ns_name_extension)
  local ns_name = 'vgit.extmarks'
  if ns_name_extension then ns_name = ns_name .. '.' .. ns_name_extension end
  local ns_id = vim.api.nvim_create_namespace(ns_name)

  return {
    ['$bufnr'] = bufnr,
    ['$ns_id'] = ns_id,
  }
end

function Extmark:derive_id(col)
  return col + 1
end

function Extmark:highlight_pattern(opts)
  local hl = opts.hl
  local row = opts.row
  local pattern = opts.pattern
  local priority = opts.priority

  local result = {}
  local lines
  if row ~= nil then
    lines = vim.api.nvim_buf_get_lines(self.bufnr, row, row + 1, false)
    if #lines == 0 then return true, result end
    local j = 0
    local line = lines[1]
    while true do
      local from, to = line:find(pattern, j + 1)
      if from == nil then break end
      local extmark_opts = {
        end_col = to,
        hl_group = hl,
      }
      if priority then extmark_opts.priority = priority end
      local ok, value = pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, from - 1, extmark_opts)
      if not ok then return false, value end
      j = from
      result[#result + 1] = value
    end
  else
    lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    for i = 1, #lines do
      local j = 0
      local line = lines[i]
      while true do
        local from, to = line:find(pattern, j + 1)
        if from == nil then break end
        local extmark_opts = {
          end_col = to,
          hl_group = hl,
        }
        if priority then extmark_opts.priority = priority end
        local ok, value = pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, i - 1, from - 1, extmark_opts)
        if not ok then return false, value end
        j = from
        result[#result + 1] = value
      end
    end
  end

  return true, result
end

function Extmark:highlight_line(opts)
  local hl = opts.hl
  local row = opts.row
  local priority = opts.priority

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, 0, {
    line_hl_group = hl,
    priority = priority,
  })
end

function Extmark:highlight_range(opts)
  local hl = opts.hl
  local row = opts.row
  local col_range = opts.col_range
  local priority = opts.priority

  local extmark_opts = {
    end_col = col_range.to,
    hl_group = hl,
  }
  if priority then extmark_opts.priority = priority end

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, col_range.from, extmark_opts)
end

function Extmark:highlight(opts)
  if opts.pattern then return self:highlight_pattern(opts) end
  if opts.line_hl then return self:highlight_line(opts) end
  return self:highlight_range(opts)
end

function Extmark:text(opts)
  local hl = opts.hl
  local row = opts.row
  local col = opts.col
  local text = opts.text
  local priority = opts.priority
  local pos = opts.pos or 'overlay'
  local hl_mode = opts.hl_mode or 'combine'
  local virt_text = opts.texts or { { text, hl } }

  local id = self:derive_id(row)
  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, col, {
    id = id,
    virt_text = virt_text,
    virt_text_pos = pos,
    hl_mode = hl_mode,
    priority = priority,
  })
end

function Extmark:lnum(opts)
  local hl = opts.hl
  local row = opts.row
  local text = opts.text
  local priority = opts.priority
  local hl_mode = opts.hl_mode or 'combine'

  local id = self:derive_id(row)
  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_text = { { text, hl } },
    virt_text_pos = 'inline',
    hl_mode = hl_mode,
    priority = priority,
  })
end

function Extmark:sign(sign)
  local row = sign.row
  local name = sign.name
  local priority = sign.priority or get_sign_priority()

  local id = self:derive_id(row)
  local sign_definition = get_sign_definition(name)
  local sign_text = sign_definition.text

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, 0, {
    id = id,
    sign_text = sign_text,
    sign_hl_group = sign_definition.texthl,
    line_hl_group = sign_definition.linehl,
    priority = priority,
  })
end

function Extmark:clear(from_row, to_row)
  from_row = from_row or 0
  to_row = to_row or -1

  if to_row ~= -1 then to_row = to_row + 1 end

  return pcall(vim.api.nvim_buf_clear_namespace, self.bufnr, self.ns_id, from_row, to_row)
end

return Extmark
