local lazy = require('vgit.core.lazy')

local vgit_diff = lazy('vgit.diff')
local core_patch = lazy('vgit.core.patch')

local patch = {}

patch.CONTEXT = 3

local function kind_of(meta)
  if not meta or meta.type == 'blank' then return 'blank' end
  if meta.type ~= 'code' then return 'file' end
  if meta.is_header then return 'hunk' end

  local change = meta.lnum_change and meta.lnum_change.type

  if change == 'add' or change == 'remove' or change == 'void' then return change end

  return 'context'
end

local function stat_of(entries)
  local stat = { added = 0, removed = 0 }

  for _, entry in ipairs(entries or {}) do
    local s = entry.diff and entry.diff.stat

    if s then
      stat.added = stat.added + (s.added or 0)
      stat.removed = stat.removed + (s.removed or 0)
    end
  end

  return stat
end

local function build_entries(files, opts)
  local entries = {}

  for _, file in ipairs(files) do
    local old_lines, new_lines = file.old_lines or {}, file.new_lines or {}

    entries[#entries + 1] = {
      type = 'diff_file',
      filename = file.filename,
      filetype = file.filetype or '',
      diff = vgit_diff.compute(old_lines, new_lines),
      original_lines = old_lines,
      current_lines = new_lines,
      header = opts.header,
      context = opts.context or patch.CONTEXT,
    }
  end

  return entries
end

function patch.build(files, opts)
  opts = opts or {}

  local entries = build_entries(files, opts)
  local layout = core_patch.build(entries, opts)

  layout.entries = entries

  return layout
end

function patch.project(layout, opts)
  opts = opts or {}

  local rows = {}

  for i = 1, #layout.lines do
    local meta = layout.line_metadata[i]

    rows[i] = {
      kind = kind_of(meta),
      old_lnum = meta and meta.old_lnum,
      new_lnum = meta and meta.new_lnum,
      filename = meta and meta.filename,
      number = layout.line_numbers[i],
    }
  end

  return {
    schema = 1,
    lines = layout.lines,
    rows = rows,
    highlights = layout.highlights,
    words = layout.words,
    stat = opts.stat or { added = 0, removed = 0 },
  }
end

function patch.data(files, opts)
  local layout = patch.build(files, opts)

  return patch.project(layout, { stat = stat_of(layout.entries) })
end

return patch
