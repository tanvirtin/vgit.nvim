local PatchLineBuilder = require('vgit.core.patch.PatchLineBuilder')
local core_style = require('vgit.core.style')
local core_words = require('vgit.core.words')

local patch = {}

patch.CONTEXT = 3

function patch.build(entries, opts)
  opts = opts or {}

  local lines, line_metadata, file_sections, marks, line_numbers, raw_lnums, max_lnum = PatchLineBuilder.build(entries)

  local highlights = (opts.style or core_style.annotate)(lines, line_metadata)
  local words = {}

  if opts.words ~= false then words = (opts.words or core_words.overlays)(lines, line_metadata) end

  return {
    lines = lines,
    line_metadata = line_metadata,
    file_sections = file_sections,
    marks = marks,
    line_numbers = line_numbers,
    raw_lnums = raw_lnums,
    max_lnum = max_lnum,
    highlights = highlights,
    words = words,
  }
end

return patch
