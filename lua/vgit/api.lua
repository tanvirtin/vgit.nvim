local lazy = require('vgit.core.lazy')

local fs = lazy('vgit.core.fs')
local vgit_diff = lazy('vgit.diff')
local vgit_patch = lazy('vgit.patch')
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

local WORD_GROUP = { word_add = 'GitWordAdd', word_delete = 'GitWordDelete' }

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

local function map_word_groups(words)
  for _, word in ipairs(words or {}) do
    for _, text in ipairs(word.texts or {}) do
      text[2] = WORD_GROUP[text[2]] or text[2]
    end
  end

  return words
end

function api.diff(old_lines, new_lines, opts)
  opts = opts or {}

  if opts.groups then ensure_highlights() end

  local data = vgit_diff.data(old_lines, new_lines, opts)

  if opts.groups then data.words = map_word_groups(data.words) end

  return data
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

local function stat_of(entries)
  local stat = { added = 0, removed = 0 }

  for _, entry in ipairs(entries) do
    local s = entry.diff and entry.diff.stat

    if s then
      stat.added = stat.added + (s.added or 0)
      stat.removed = stat.removed + (s.removed or 0)
    end
  end

  return stat
end

function api.patch(files, opts)
  opts = opts or {}

  if opts.groups or opts.syntax then ensure_highlights() end

  local prepared = {}

  for _, file in ipairs(files) do
    prepared[#prepared + 1] = {
      filename = file.filename,
      filetype = filetype_of(file),
      old_lines = file.old_lines,
      new_lines = file.new_lines,
    }
  end

  local layout = vgit_patch.build(prepared, {
    style = opts.groups and DiffStyleAnnotator.annotate or nil,
    words = opts.groups and word_overlays or nil,
    header = opts.header,
    context = opts.context or api.CONTEXT,
  })

  if opts.syntax then add_syntax(layout.highlights, layout.lines, layout.file_sections) end

  local data = vgit_patch.project(layout, { stat = stat_of(layout.entries) })

  if opts.groups then
    for _, row in ipairs(data.rows) do
      local number = row.number

      if number then row.number = { text = number.text, hl = DiffStyleAnnotator.line_group(number.role) } end
    end
  end

  return data
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
      diff = vgit_diff.compute(file.old_lines or {}, file.new_lines or {}, { layout = layout }),
      keymaps = spec.keymaps,
    })

    return true
  end

  local entries = {}

  for _, file in ipairs(files) do
    local old_lines, new_lines = file.old_lines or {}, file.new_lines or {}

    entries[#entries + 1] = {
      status = { filename = file.filename, filetype = filetype_of(file) },
      diff = vgit_diff.compute(old_lines, new_lines, { layout = layout }),
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
