local PatchLineBuilder = require('vgit.core.patch.PatchLineBuilder')

local patch = {}

patch.CONTEXT = 3

function patch.build(entries, opts)
  opts = opts or {}

  local lines, line_metadata, file_sections, marks, line_numbers, raw_lnums, max_lnum = PatchLineBuilder.build(entries)

  return {
    lines = lines,
    line_metadata = line_metadata,
    file_sections = file_sections,
    marks = marks,
    line_numbers = line_numbers,
    raw_lnums = raw_lnums,
    max_lnum = max_lnum,
    highlights = opts.style and opts.style(lines, line_metadata) or {},
    words = opts.words and opts.words(lines, line_metadata) or {},
  }
end

return patch
