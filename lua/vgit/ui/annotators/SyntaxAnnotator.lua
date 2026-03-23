local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local Buffer = lazy('vgit.core.Buffer')

local SyntaxAnnotator = Object:extend()

function SyntaxAnnotator:constructor()
  return {
    _cache = {},
    _cache_max = 50,
    _cache_order = {},
    _scratch_buffer = nil,
  }
end

function SyntaxAnnotator:_cache_key(lines, filetype)
  local n = #lines
  if n == 0 then return nil end
  local q1 = lines[math.floor(n * 0.25) + 1] or ''
  local q2 = lines[math.floor(n * 0.50) + 1] or ''
  local q3 = lines[math.floor(n * 0.75) + 1] or ''
  return string.format('%s:%d:%s:%s:%s:%s:%s', filetype or '', n, lines[1] or '', q1, q2, q3, lines[n] or '')
end

function SyntaxAnnotator:_cache_put(key, value)
  if not self._cache[key] then self._cache_order[#self._cache_order + 1] = key end
  self._cache[key] = value
  while #self._cache_order > self._cache_max do
    local oldest = table.remove(self._cache_order, 1)
    self._cache[oldest] = nil
  end
end

function SyntaxAnnotator:clear_cache()
  self._cache = {}
  self._cache_order = {}
end

function SyntaxAnnotator:dispose()
  if self._scratch_buffer and self._scratch_buffer:is_valid() then self._scratch_buffer:delete() end
  self._scratch_buffer = nil
  self:clear_cache()
end

function SyntaxAnnotator:_parse_highlights(scratch_buffer, filetype)
  local highlights = {}
  local bufnr = scratch_buffer.bufnr

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, filetype)
  if not ok or not parser then return highlights end

  local query_ok, query = pcall(vim.treesitter.query.get, filetype, 'highlights')
  if not query_ok or not query then return highlights end

  local tree = parser:parse()[1]
  if not tree then return highlights end

  local root = tree:root()

  for id, node, _ in query:iter_captures(root, bufnr, 0, -1) do
    local name = query.captures[id]
    local start_row, start_col, end_row, end_col = node:range()

    for row = start_row, end_row do
      local col_start = (row == start_row) and start_col or 0
      local col_end = (row == end_row) and end_col or -1

      highlights[#highlights + 1] = {
        row = row,
        col_start = col_start,
        col_end = col_end,
        hl_group = '@' .. name,
      }
    end
  end

  return highlights
end

function SyntaxAnnotator:annotate(lines, filetype)
  if not lines or #lines == 0 then return {} end

  if not filetype or filetype == '' or filetype == 'text' then return {} end

  local key = self:_cache_key(lines, filetype)
  if key and self._cache[key] then return self._cache[key] end

  if not self._scratch_buffer or not self._scratch_buffer:is_valid() then
    self._scratch_buffer = Buffer():create(false, true)
  end

  local scratch_buffer = self._scratch_buffer
  scratch_buffer:set_lines(lines)
  scratch_buffer:set_option('filetype', filetype)

  local highlights = self:_parse_highlights(scratch_buffer, filetype)

  if key then self:_cache_put(key, highlights) end

  return highlights
end

return SyntaxAnnotator
