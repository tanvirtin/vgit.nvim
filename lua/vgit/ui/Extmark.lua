local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local signs_setting = lazy('vgit.settings.signs')

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

local ID_GROUPS = {
  text = 10,
  sign = 100,
  lnum = 1000,
  virt_line = 10000,
}

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

function Extmark:derive_id(row, kind)
  local base = ID_GROUPS[kind]
  if not base then error('invalid extmark group') end
  return base + row
end

function Extmark:_highlight_pattern_line(line, line_row, pattern, hl, priority, result)
  local j = 0
  while true do
    local from, to = line:find(pattern, j + 1)
    if from == nil then break end
    local ok, value = pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, line_row, from - 1, {
      end_col = to,
      hl_group = hl,
      priority = priority,
    })
    if not ok then return false, value end
    j = to
    if to < from then break end
    result[#result + 1] = value
  end
  return true
end

function Extmark:highlight_pattern(opts)
  local hl = opts.hl
  local row = opts.row
  local pattern = opts.pattern
  local priority = opts.priority

  local result = {}
  if row ~= nil then
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, row, row + 1, false)
    if #lines == 0 then return true, result end
    local ok, err = self:_highlight_pattern_line(lines[1], row, pattern, hl, priority, result)
    if not ok then return false, err end
  else
    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 0, -1, false)
    for i = 1, #lines do
      local ok, err = self:_highlight_pattern_line(lines[i], i - 1, pattern, hl, priority, result)
      if not ok then return false, err end
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

  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, col_range.from, {
    end_col = col_range.to,
    hl_group = hl,
    priority = priority,
  })
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

  local id = self:derive_id(row, 'text')
  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, col, {
    id = id,
    virt_text = virt_text,
    virt_text_pos = pos,
    hl_mode = hl_mode,
    priority = priority,
  })
end

function Extmark:virt_line(opts)
  local hl = opts.hl
  local row = opts.row
  local text = opts.text
  local priority = opts.priority
  local above = opts.above
  if above == nil then above = true end

  local id = self:derive_id(row, 'virt_line')
  return pcall(vim.api.nvim_buf_set_extmark, self.bufnr, self.ns_id, row, 0, {
    id = id,
    virt_lines = { { { text, hl } } },
    virt_lines_above = above,
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

function Extmark:sign(opts)
  local row = opts.row
  local name = opts.name
  local priority = opts.priority or get_sign_priority()

  local id = self:derive_id(row, 'sign')
  local sign_definition = get_sign_definition(name)
  if not sign_definition then return false, 'unknown sign: ' .. tostring(name) end
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
