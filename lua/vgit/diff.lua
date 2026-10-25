local lazy = require('vgit.core.lazy')

local Diff = lazy('vgit.core.diff.Diff')
local git_hunks = lazy('vgit.git.git_hunks')
local core_words = lazy('vgit.core.words')

local diff = {}

function diff.compute(old_lines, new_lines, opts)
  opts = opts or {}

  local layout = opts.layout or 'unified'

  if #old_lines == 0 and #new_lines > 0 then
    return Diff():generate(git_hunks.custom(new_lines, { untracked = true }), new_lines, layout)
  end

  if #new_lines == 0 and #old_lines > 0 then
    return Diff():generate(git_hunks.custom(old_lines, { deleted = true }), old_lines, layout, { is_deleted = true })
  end

  return Diff():generate(git_hunks.live(nil, old_lines, new_lines), new_lines, layout)
end

local function change_line(change)
  local pair = change.word_pair
  if not pair then return nil end

  if change.type == 'remove' then return pair.removed end
  if change.type == 'add' then return pair.added end
end

local function project_hunk(hunk)
  return {
    header = hunk.header,
    top = hunk.top,
    bot = hunk.bot,
    type = hunk.type,
    diff = hunk.diff,
    stat = hunk.stat,
  }
end

function diff.project(model, opts)
  opts = opts or {}

  local changes, words, hunks = {}, {}, {}

  for _, change in ipairs(model.lnum_changes or {}) do
    changes[#changes + 1] = {
      lnum = change.lnum,
      buftype = change.buftype,
      type = change.type,
    }

    if opts.words ~= false then
      local line = change_line(change)
      local overlay = line and core_words.overlay_for(change, line)

      if overlay then
        words[#words + 1] = {
          buftype = change.buftype,
          lnum = change.lnum,
          col = overlay.col,
          texts = overlay.texts,
        }
      end
    end
  end

  for _, hunk in ipairs(model.hunks or {}) do
    hunks[#hunks + 1] = project_hunk(hunk)
  end

  return {
    schema = 1,
    lines = model.lines,
    previous_lines = model.previous_lines,
    current_lines = model.current_lines,
    changes = changes,
    hunks = hunks,
    marks = model.marks or {},
    stat = model.stat or { added = 0, removed = 0 },
    words = words,
  }
end

function diff.data(old_lines, new_lines, opts)
  return diff.project(diff.compute(old_lines, new_lines, opts), opts)
end

return diff
