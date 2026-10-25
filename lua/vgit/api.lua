local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local Diff = lazy('vgit.core.diff.Diff')
local patch = lazy('vgit.core.patch')
local git_hunks = lazy('vgit.git.git_hunks')
local sign = lazy('vgit.core.sign')
local highlight = lazy('vgit.core.highlight')
local git_setting = lazy('vgit.settings.git')
local scene_setting = lazy('vgit.settings.scene')
local display_service = lazy('vgit.ui.display_service')
local DiffAnnotator = lazy('vgit.ui.annotators.DiffAnnotator')
local DiffStyleAnnotator = lazy('vgit.ui.annotators.DiffStyleAnnotator')
local SyntaxMappingAnnotator = lazy('vgit.ui.annotators.SyntaxMappingAnnotator')

local api = {}

api.CONTEXT = 3

local highlights_registered = false

local function ensure_highlights()
  if highlights_registered then return end

  highlights_registered = true

  if vim.tbl_isempty(highlight.get_hl_by_name('GitWordAdd')) then highlight.register_module(sign.register_module) end
end

local function filetype_of(file)
  if file.filetype and file.filetype ~= '' then return file.filetype end
  if not file.filename then return '' end

  return fs.detect_filetype(file.filename) or ''
end

function api.diff(old_lines, new_lines, opts)
  opts = opts or {}

  ensure_highlights()

  local layout = opts.layout or 'unified'

  if #old_lines == 0 and #new_lines > 0 then
    return Diff():generate(git_hunks.custom(new_lines, { untracked = true }), new_lines, layout)
  end

  if #new_lines == 0 and #old_lines > 0 then
    return Diff():generate(git_hunks.custom(old_lines, { deleted = true }), old_lines, layout, { is_deleted = true })
  end

  return Diff():generate(git_hunks.live(nil, old_lines, new_lines), new_lines, layout)
end

local function kind_of(meta)
  if not meta or meta.type == 'blank' then return 'blank' end
  if meta.type ~= 'code' then return 'file' end
  if meta.is_header then return 'hunk' end

  local change = meta.lnum_change and meta.lnum_change.type

  if change == 'add' or change == 'remove' or change == 'void' then return change end

  return 'context'
end

function api.words(lnum_change, line)
  return DiffAnnotator.word_overlay_for(lnum_change, line)
end

local function word_overlays(lines, line_metadata)
  local words = {}

  for i, meta in ipairs(line_metadata) do
    local overlay = DiffAnnotator.word_overlay_for(meta and meta.lnum_change, lines[i])

    if overlay then words[#words + 1] = { row = i - 1, col = overlay.col, texts = overlay.texts } end
  end

  return words
end

local function add_syntax(highlights, lines, file_sections)
  local annotator = SyntaxMappingAnnotator()

  for _, section in ipairs(file_sections) do
    for _, hl in
      ipairs(annotator:annotate({
        original_lines = section.original_lines,
        current_lines = section.current_lines,
        filetype = section.filetype,
        syntax_mappings = section.syntax_mappings,
      }))
    do
      local line = lines[hl.row + 1] or ''

      highlights[#highlights + 1] = {
        row = hl.row,
        col_start = hl.col_start,
        col_end = hl.col_end >= 0 and hl.col_end or #line,
        hl_group = hl.hl_group,
        syntax = true,
      }
    end
  end

  annotator:dispose()
end

function api.patch(files, opts)
  opts = opts or {}

  local entries, stat = {}, { added = 0, removed = 0 }

  for _, file in ipairs(files) do
    local old_lines, new_lines = file.old_lines or {}, file.new_lines or {}
    local diff = api.diff(old_lines, new_lines)

    if diff.stat then
      stat.added = stat.added + diff.stat.added
      stat.removed = stat.removed + diff.stat.removed
    end

    entries[#entries + 1] = {
      type = 'diff_file',
      filename = file.filename,
      filetype = filetype_of(file),
      diff = diff,
      original_lines = old_lines,
      current_lines = new_lines,
      header = opts.header,
      context = opts.context or api.CONTEXT,
    }
  end

  local layout = patch.build(entries, {
    style = DiffStyleAnnotator.annotate,
    words = word_overlays,
  })

  if opts.syntax ~= false then add_syntax(layout.highlights, layout.lines, layout.file_sections) end

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
    lines = layout.lines,
    rows = rows,
    highlights = layout.highlights,
    words = layout.words,
    stat = stat,
  }
end

function api.patch_text(files, opts)
  opts = opts or {}

  local out = {}

  for _, file in ipairs(files) do
    local old = table.concat(file.old_lines or {}, '\n')
    local new = table.concat(file.new_lines or {}, '\n')

    if old ~= '' then old = old .. '\n' end
    if new ~= '' then new = new .. '\n' end

    local text = vim.diff(old, new, {
      ctxlen = opts.context or api.CONTEXT,
      algorithm = git_setting:get('algorithm'),
    }) or ''

    if text ~= '' then
      if opts.header ~= false then
        out[#out + 1] = '--- ' .. (file.filename or 'a')
        out[#out + 1] = '+++ ' .. (file.filename or 'b')
      end

      for _, line in ipairs(vim.split(text:gsub('\n$', ''), '\n', { plain = true })) do
        out[#out + 1] = line
      end
    end
  end

  return out
end

function api.show(spec)
  ensure_highlights()

  local files = spec.files or {}

  if #files == 0 then return false end

  local layout = spec.layout or scene_setting:get('diff_preference') or 'unified'

  if #files == 1 then
    local file = files[1]

    display_service.show_diff({
      type = 'file',
      is_content = true,
      is_live = false,
      cursor_line = true,
      target_hunk_index = 1,
      filename = file.filename,
      filetype = filetype_of(file),
      layout_type = layout,
      diff = api.diff(file.old_lines or {}, file.new_lines or {}, { layout = layout }),
      keymaps = spec.keymaps,
    })

    return true
  end

  local entries = {}

  for _, file in ipairs(files) do
    local old_lines, new_lines = file.old_lines or {}, file.new_lines or {}

    entries[#entries + 1] = {
      status = { filename = file.filename, filetype = filetype_of(file) },
      diff = api.diff(old_lines, new_lines, { layout = layout }),
      original_lines = old_lines,
      current_lines = new_lines,
    }
  end

  display_service.show_diff({
    type = 'files',
    is_content = true,
    layout_type = layout,
    entries = { { entries = entries } },
    keymaps = spec.keymaps,
  })

  return true
end

return api
