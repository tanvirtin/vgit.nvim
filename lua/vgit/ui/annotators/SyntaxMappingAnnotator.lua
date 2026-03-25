local lazy = require('vgit.core.lazy')

local Object = lazy('vgit.core.Object')
local SyntaxAnnotator = lazy('vgit.ui.annotators.SyntaxAnnotator')

local SyntaxMappingAnnotator = Object:extend()

function SyntaxMappingAnnotator:constructor()
  return {
    _syntax_annotator = SyntaxAnnotator(),
  }
end

function SyntaxMappingAnnotator:clear_cache()
  self._syntax_annotator:clear_cache()
end

function SyntaxMappingAnnotator:dispose()
  if self._syntax_annotator then self._syntax_annotator:dispose() end
end

function SyntaxMappingAnnotator:_build_source_map(highlights)
  local map = {}

  for _, hl in ipairs(highlights) do
    local line = hl.row + 1

    if not map[line] then map[line] = {} end

    local line_hls = map[line]
    line_hls[#line_hls + 1] = {
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    }
  end

  return map
end

function SyntaxMappingAnnotator:_map_highlights(result, hl_map, source_line, target_row)
  local line_hls = hl_map[source_line]
  if not line_hls then return end

  for _, hl in ipairs(line_hls) do
    result[#result + 1] = {
      row = target_row,
      col_start = hl.col_start,
      col_end = hl.col_end,
      hl_group = hl.hl_group,
    }
  end
end

function SyntaxMappingAnnotator:annotate(opts)
  if not opts then return {} end

  local original_lines = opts.original_lines or {}
  local current_lines = opts.current_lines or {}
  local filetype = opts.filetype
  local syntax_mappings = opts.syntax_mappings or {}

  if #syntax_mappings == 0 then return {} end
  if not filetype or filetype == '' or filetype == 'text' then return {} end

  local all_highlights = {}

  local orig_hl_map = {}
  if #original_lines > 0 then
    local orig_highlights = self._syntax_annotator:annotate(original_lines, filetype)
    orig_hl_map = self:_build_source_map(orig_highlights)
  end

  local curr_hl_map = {}
  if #current_lines > 0 then
    local curr_highlights = self._syntax_annotator:annotate(current_lines, filetype)
    curr_hl_map = self:_build_source_map(curr_highlights)
  end

  for _, mapping in ipairs(syntax_mappings) do
    local hl_map = mapping.source == 'original' and orig_hl_map or curr_hl_map
    self:_map_highlights(all_highlights, hl_map, mapping.source_line, mapping.display_row)
  end

  return all_highlights
end

return SyntaxMappingAnnotator
