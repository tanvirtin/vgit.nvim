local Object = require('vgit.core.Object')
local signs_setting = require('vgit.settings.signs')

local Extmark = Object:extend()

function Extmark:constructor(bufnr, ns_name_extension)
  local ns_name = 'vgit.extmarks'
  if ns_name_extension then
    ns_name = ns_name .. '.' .. ns_name_extension
  end
  local ns_id = vim.api.nvim_create_namespace(ns_name)

  return {
    bufnr = bufnr,
    groups = {
      text = 10,
      sign = 100,
      lnum = 1000,
    },
    ns_id = ns_id,
  }
end

function Extmark:derive_id(col, name)
  local base = self.groups[name]
  if not base then error('invalid extmark group') end
  return base + col
end

function Extmark:highlight(opts)
  local hl = opts.hl
  local row = opts.row
  local pattern = opts.pattern
  local col_range = opts.col_range

  if pattern then
    local result = {}
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)

    for i = 1, #lines do
      local j = 0
      local line = lines[i]

      if i - 1 == row or row == nil then
        while true do
          local from, to = line:find(pattern, j + 1)
          if from == nil then break end

          local ok, value = self:highlight({
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
    end

    return true, result
  end

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, col_range.from, {
    end_col = col_range.to,
    hl_group = hl,
  })
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

  local id = self:derive_id(row, 'text')
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

  local id = self:derive_id(row, 'lnum')
  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_text = { { text, hl } },
    virt_text_pos = 'inline',
    hl_mode = hl_mode,
    priority = priority,
  })
end

function Extmark:sign(sign)
  local col = sign.col
  local name = sign.name
  local priority = sign.priority or signs_setting:get('priority')

  local id = self:derive_id(col, 'sign')
  local definitions = signs_setting:get('definitions')
  local sign_definition = definitions[name]
  local sign_text = sign_definition.text

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, col, 0, {
    id = id,
    sign_text = sign_text,
    sign_hl_group = sign_definition.texthl,
    line_hl_group = sign_definition.linehl,
    priority = priority,
  })
end

function Extmark:clear(from_col, to_col)
  from_col = from_col or 0
  to_col = to_col or -1

  if to_col ~= -1 then to_col = to_col + 1 end

  return pcall(vim.api.nvim_buf_clear_namespace, self.bufnr, self.ns_id, from_col, to_col)
end

return Extmark
