local lazy = require('vgit.core.lazy')

local core_style = require('vgit.core.style')
local signs_setting = lazy('vgit.settings.signs')

local DiffStyleAnnotator = {}

local GROUPS = {
  separator = 'GitPatchSeparator',
  filename = 'GitPatchFileHeader',
  header = 'GitPatchHeader',
  header_marker = 'GitPatchHeaderMarker',
  header_remove = 'GitPatchHeaderRemove',
  header_add = 'GitPatchHeaderAdd',
  context = 'GitPatchContext',
}

local LINE_GROUPS = {
  add = 'GitSignsAdd',
  remove = 'GitSignsDelete',
  context = 'GitLineNr',
  header = 'GitPatchHeader',
}

local function map(highlights, scene_hls)
  local result = {}

  for _, hl in ipairs(highlights) do
    local group = GROUPS[hl.role] or scene_hls[hl.role]

    if group then
      result[#result + 1] = {
        row = hl.row,
        col_start = hl.col_start,
        col_end = hl.col_end,
        hl_group = group,
        line = hl.line,
      }
    end
  end

  return result
end

function DiffStyleAnnotator._annotate_header(line, row)
  return map(core_style.header(line, row), {})
end

function DiffStyleAnnotator.annotate(lines, line_metadata)
  return map(core_style.annotate(lines, line_metadata), signs_setting:get('usage').scene)
end

function DiffStyleAnnotator.line_group(role)
  return LINE_GROUPS[role] or 'GitLineNr'
end

return DiffStyleAnnotator
