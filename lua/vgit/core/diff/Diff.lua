local dmp = require('vgit.vendor.dmp')
local utils = require('vgit.core.utils')
local Object = require('vgit.core.Object')

local MAX_LINES = 4

local Diff = Object:extend()

function Diff:constructor(opts)
  opts = opts or {}

  return utils.object.extend({
    hunks = {},
    marks = {},
    lines = {},
    lnum_changes = {},
    current_lines = {},
    previous_lines = {},
    stat = { added = 0, removed = 0 },
  }, opts)
end

function Diff:generate_unified_conflict(conflicts, lines)
  local marks = {}
  local marks_len = 0
  local lnum_changes = {}
  local lnum_changes_len = 0

  for i = 1, #conflicts do
    local conflict = conflicts[i]
    local current = conflict.current
    local ancestor = conflict.ancestor
    local middle = conflict.middle
    local incoming = conflict.incoming

    local top = current.top
    local bot = incoming.bot

    marks_len = marks_len + 1
    marks[marks_len] = {
      type = 'conflict',
      top = top,
      bot = bot,
      top_relative = top,
      bot_relative = bot,
    }

    lnum_changes_len = lnum_changes_len + 1
    lnum_changes[lnum_changes_len] = {
      lnum = current.top,
      buftype = 'current',
      type = 'conflict_current_mark',
    }

    for lnum = current.top + 1, current.bot do
      lnum_changes_len = lnum_changes_len + 1
      lnum_changes[lnum_changes_len] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_current',
      }
    end

    if ancestor and not utils.list.is_empty(ancestor) then
      lnum_changes_len = lnum_changes_len + 1
      lnum_changes[lnum_changes_len] = {
        lnum = ancestor.top,
        buftype = 'current',
        type = 'conflict_ancestor_mark',
      }
      for lnum = ancestor.top + 1, ancestor.bot do
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = lnum,
          buftype = 'current',
          type = 'conflict_ancestor',
        }
      end
    end

    for lnum = middle.top, middle.bot do
      lnum_changes_len = lnum_changes_len + 1
      lnum_changes[lnum_changes_len] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_middle',
      }
    end

    for lnum = incoming.top, incoming.bot - 1 do
      lnum_changes_len = lnum_changes_len + 1
      lnum_changes[lnum_changes_len] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_incoming',
      }
    end

    lnum_changes_len = lnum_changes_len + 1
    lnum_changes[lnum_changes_len] = {
      lnum = incoming.bot,
      buftype = 'current',
      type = 'conflict_incoming_mark',
    }
  end

  return utils.object.extend(self, {
    lines = lines,
    hunks = {},
    marks = marks,
    lnum_changes = lnum_changes,
    stat = { added = 0, removed = 0 },
  })
end

function Diff:generate_split_conflict(conflicts, lines)
  local marks = {}
  local lnum_changes = {}
  local previous_lines = {}
  local current_lines = {}

  for key, value in pairs(lines) do
    previous_lines[key] = value
    current_lines[key] = value
  end

  for i = 1, #conflicts do
    local conflict = conflicts[i]
    local current = conflict.current
    local ancestor = conflict.ancestor
    local middle = conflict.middle
    local incoming = conflict.incoming

    local top = current.top
    local bot = incoming.bot

    marks[#marks + 1] = {
      type = 'conflict',
      top = top,
      bot = bot,
      top_relative = top,
      bot_relative = bot,
    }

    previous_lines[current.top] = ''
    lnum_changes[#lnum_changes + 1] = {
      lnum = current.top,
      buftype = 'current',
      type = 'conflict_current_mark',
    }
    lnum_changes[#lnum_changes + 1] = {
      lnum = current.top,
      buftype = 'previous',
      type = 'void',
    }

    for lnum = current.top + 1, current.bot do
      previous_lines[lnum] = ''
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_current',
      }
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'previous',
        type = 'void',
      }
    end

    if ancestor and not utils.list.is_empty(ancestor) then
      lnum_changes[#lnum_changes + 1] = {
        lnum = ancestor.top,
        buftype = 'previous',
        type = 'conflict_ancestor_mark',
      }
      lnum_changes[#lnum_changes + 1] = {
        lnum = ancestor.top,
        buftype = 'current',
        type = 'conflict_ancestor_mark',
      }
      for lnum = ancestor.top + 1, ancestor.bot do
        lnum_changes[#lnum_changes + 1] = {
          lnum = lnum,
          buftype = 'previous',
          type = 'conflict_ancestor',
        }
        lnum_changes[#lnum_changes + 1] = {
          lnum = lnum,
          buftype = 'current',
          type = 'conflict_ancestor',
        }
      end
    end

    for lnum = middle.top, middle.bot do
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_middle',
      }
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'previous',
        type = 'conflict_middle',
      }
    end

    current_lines[incoming.top] = ''
    lnum_changes[#lnum_changes + 1] = {
      lnum = incoming.bot,
      buftype = 'previous',
      type = 'conflict_incoming_mark',
    }
    lnum_changes[#lnum_changes + 1] = {
      lnum = incoming.top,
      buftype = 'current',
      type = 'void',
    }
    for lnum = incoming.top, incoming.bot - 1 do
      current_lines[lnum] = ''
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'previous',
        type = 'conflict_incoming',
      }
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'current',
        type = 'void',
      }
    end
    lnum_changes[#lnum_changes + 1] = {
      lnum = incoming.bot,
      buftype = 'current',
      type = 'void',
    }
  end

  return utils.object.extend(self, {
    hunks = {},
    marks = marks,
    lnum_changes = lnum_changes,
    previous_lines = previous_lines,
    current_lines = current_lines,
    stat = { added = 0, removed = 0 },
  })
end

function Diff:generate_unified_deleted(hunks, lines)
  if #hunks == 0 then return utils.object.extend(self, {
    lines = lines,
    hunks = hunks,
  }) end

  local hunk = hunks[1]
  local type = hunk.type
  local diff = hunk.diff
  local top = 1
  local bot = hunk.bot
  local lnum_changes = {}
  local s = top

  for _ = 1, #diff do
    lnum_changes[#lnum_changes + 1] = {
      lnum = s,
      type = 'remove',
      buftype = 'current',
    }
    s = s + 1
  end

  return utils.object.extend(self, {
    lines = lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = {
      {
        type = type,
        top = top,
        bot = bot,
      },
    },
    stat = hunk.stat,
  })
end

function Diff:generate_split_deleted(hunks, lines)
  if #hunks == 0 then
    return utils.object.extend(self, {
      current_lines = {},
      previous_lines = lines,
      hunks = hunks,
    })
  end

  local hunk = hunks[1]
  local type = hunk.type
  local diff = hunk.diff
  local top = 1
  local bot = hunk.bot
  local s = top
  local lnum_changes = {}
  local current_lines = {}

  for _ = 1, #diff do
    current_lines[#current_lines + 1] = ''
    lnum_changes[#lnum_changes + 1] = {
      lnum = s,
      buftype = 'previous',
      type = 'remove',
    }
    lnum_changes[#lnum_changes + 1] = {
      lnum = s,
      buftype = 'current',
      type = 'void',
    }
    s = s + 1
  end

  return utils.object.extend(self, {
    previous_lines = lines,
    current_lines = current_lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = {
      {
        type = type,
        top = top,
        bot = bot,
      },
    },
    stat = hunk.stat,
  })
end

function Diff:generate_unified(hunks, lines)
  if #hunks == 0 then return utils.object.extend(self, {
    lines = lines,
    hunks = hunks,
  }) end

  -- Build new_lines by appending segments instead of table.insert(tbl, pos, val)
  -- which avoids O(n²) element shifting for large diffs.
  local new_lines = {}
  local new_lines_len = 0
  local lnum_changes = {}
  local lnum_changes_len = 0
  local marks = {}
  local marks_len = 0
  local stat = {
    added = 0,
    removed = 0,
  }

  local lines_len = #lines
  local hunks_len = #hunks
  local new_lines_added = 0
  local src_pos = 1 -- next original line to copy

  for i = 1, hunks_len do
    local hunk = hunks[i]
    local type = hunk.type
    local diff = hunk.diff
    local orig_top = hunk.top
    local orig_bot = hunk.bot
    local top = orig_top + new_lines_added
    local bot = orig_bot + new_lines_added
    local hunk_stat = hunk.stat

    stat.added = stat.added + hunk_stat.added
    stat.removed = stat.removed + hunk_stat.removed

    if type == 'add' then
      -- Copy original lines up to and including bot (added lines are already in lines[])
      for k = src_pos, orig_bot do
        new_lines_len = new_lines_len + 1
        new_lines[new_lines_len] = lines[k]
      end
      src_pos = orig_bot + 1

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top,
        bot = bot,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = top, bot do
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = j,
          type = 'add',
          buftype = 'current',
        }
      end
    elseif type == 'remove' then
      local diff_len = #diff

      -- Copy original lines up to and including top (the line before removed content)
      for k = src_pos, orig_top do
        new_lines_len = new_lines_len + 1
        new_lines[new_lines_len] = lines[k]
      end
      src_pos = orig_top + 1

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top + 1,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      -- Append the removed lines (no shifting needed)
      local s = top
      for j = 1, diff_len do
        local line = diff[j]
        s = s + 1
        new_lines_added = new_lines_added + 1
        new_lines_len = new_lines_len + 1
        new_lines[new_lines_len] = line:sub(2, #line)
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = s,
          type = 'remove',
          buftype = 'current',
        }
      end

      marks[marks_len].bot = top + diff_len
    elseif type == 'change' then
      local removed_lines, added_lines = hunk:parse_diff()
      local diff_len = #diff

      -- Copy original lines up to but not including top (change replaces top..bot)
      for k = src_pos, orig_top - 1 do
        new_lines_len = new_lines_len + 1
        new_lines[new_lines_len] = lines[k]
      end

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      -- First pass: append '-' lines (removed content, inserted before existing)
      local s = top
      for j = 1, diff_len do
        local line = diff[j]
        local cleaned_line = line:sub(2, #line)
        local line_type = line:sub(1, 1)

        if line_type == '-' then
          local word_diff = nil

          new_lines_added = new_lines_added + 1
          new_lines_len = new_lines_len + 1
          new_lines[new_lines_len] = cleaned_line

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(cleaned_line, diff[#removed_lines + j]:sub(2, #diff[#removed_lines + j]))
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = s,
            type = 'remove',
            buftype = 'current',
            word_diff = word_diff,
          }
          s = s + 1
        end
      end

      -- Copy original lines for the '+' range (these ARE the added lines in the buffer)
      for k = orig_top, orig_bot do
        new_lines_len = new_lines_len + 1
        new_lines[new_lines_len] = lines[k]
      end
      src_pos = orig_bot + 1

      -- Second pass: record lnum_changes for '+' lines
      for j = 1, diff_len do
        local line = diff[j]
        local cleaned_line = line:sub(2, #line)
        local line_type = line:sub(1, 1)

        if line_type == '+' then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(cleaned_line, diff[j - #removed_lines]:sub(2, #diff[j - #removed_lines]))
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = s,
            type = 'add',
            buftype = 'current',
            word_diff = word_diff,
          }
          s = s + 1
        end
      end

      marks[marks_len].bot = top + diff_len - 1
    end
  end

  -- Copy remaining original lines after the last hunk
  for k = src_pos, lines_len do
    new_lines_len = new_lines_len + 1
    new_lines[new_lines_len] = lines[k]
  end

  return utils.object.extend(self, {
    lines = new_lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = marks,
    stat = stat,
  })
end

function Diff:generate_split(hunks, lines)
  if #hunks == 0 then
    return utils.object.extend(self, {
      current_lines = lines,
      previous_lines = lines,
      hunks = hunks,
    })
  end

  -- Build current_lines and previous_lines by appending segments instead of
  -- table.insert(tbl, pos, val) which avoids O(n²) element shifting.
  local new_lines_added = 0
  local current_lines = {}
  local current_len = 0
  local previous_lines = {}
  local previous_len = 0
  local lnum_changes = {}
  local lnum_changes_len = 0
  local void_line = ''
  local marks = {}
  local marks_len = 0
  local stat = {
    added = 0,
    removed = 0,
  }

  local lines_len = #lines
  local hunks_len = #hunks
  local src_pos = 1 -- next original line to copy

  for i = 1, hunks_len do
    local hunk = hunks[i]
    local type = hunk.type
    local orig_top = hunk.top
    local orig_bot = hunk.bot
    local top = orig_top + new_lines_added
    local bot = orig_bot + new_lines_added
    local diff = hunk.diff
    local hunk_stat = hunk.stat

    stat.added = stat.added + hunk_stat.added
    stat.removed = stat.removed + hunk_stat.removed

    if type == 'add' then
      -- Copy original lines up to but not including top (added lines need void in previous)
      for k = src_pos, orig_top - 1 do
        current_len = current_len + 1
        current_lines[current_len] = lines[k]
        previous_len = previous_len + 1
        previous_lines[previous_len] = lines[k]
      end
      -- Add the added lines: current gets the real lines, previous gets void
      for k = orig_top, orig_bot do
        current_len = current_len + 1
        current_lines[current_len] = lines[k]
        previous_len = previous_len + 1
        previous_lines[previous_len] = void_line
      end
      src_pos = orig_bot + 1

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top,
        bot = bot,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = top, bot do
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = j,
          buftype = 'previous',
          type = 'void',
        }
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = j,
          buftype = 'current',
          type = 'add',
        }
      end
    elseif type == 'remove' then
      local diff_len = #diff

      -- Copy original lines up to and including orig_top (the line before removed content)
      for k = src_pos, orig_top do
        current_len = current_len + 1
        current_lines[current_len] = lines[k]
        previous_len = previous_len + 1
        previous_lines[previous_len] = lines[k]
      end
      src_pos = orig_top + 1

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top + 1,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      -- Append removed lines: current gets void, previous gets the removed line
      local insert_top = top
      for j = 1, diff_len do
        local line = diff[j]
        insert_top = insert_top + 1
        new_lines_added = new_lines_added + 1

        current_len = current_len + 1
        current_lines[current_len] = void_line
        previous_len = previous_len + 1
        previous_lines[previous_len] = line:sub(2, #line)

        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = insert_top,
          buftype = 'current',
          type = 'void',
        }
        lnum_changes_len = lnum_changes_len + 1
        lnum_changes[lnum_changes_len] = {
          lnum = insert_top,
          buftype = 'previous',
          type = 'remove',
        }
      end

      marks[marks_len].bot = bot + diff_len
    elseif type == 'change' then
      -- Copy original lines up to but not including orig_top
      for k = src_pos, orig_top - 1 do
        current_len = current_len + 1
        current_lines[current_len] = lines[k]
        previous_len = previous_len + 1
        previous_lines[previous_len] = lines[k]
      end
      src_pos = orig_bot + 1

      marks_len = marks_len + 1
      marks[marks_len] = {
        type = type,
        top = top,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }
      -- Retrieve lines that have been removed and added without "-" and "+".
      local removed_lines, added_lines = hunk:parse_diff()
      -- Max lines are the maximum number of lines found between added and removed lines.
      local max_lines
      if #removed_lines > #added_lines then
        max_lines = #removed_lines
      else
        max_lines = #added_lines
      end

      -- Track extra lines added for this change hunk
      local extra = max_lines - (orig_bot - orig_top + 1)
      if extra > 0 then new_lines_added = new_lines_added + extra end

      -- Build the change region: max_lines rows for both sides
      for j = 1, max_lines do
        local added_line = added_lines[j]
        local removed_line = removed_lines[j]
        local out_lnum = top + j - 1

        current_len = current_len + 1
        current_lines[current_len] = added_line or void_line
        previous_len = previous_len + 1
        previous_lines[previous_len] = removed_line or void_line

        if removed_line then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(removed_line, added_lines[j])
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = out_lnum,
            buftype = 'previous',
            type = 'remove',
            word_diff = word_diff,
          }
        end

        if added_line then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(added_line, removed_lines[j])
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = out_lnum,
            buftype = 'current',
            type = 'add',
            word_diff = word_diff,
          }
        end

        if added_line and not removed_line then
          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = out_lnum,
            buftype = 'previous',
            type = 'void',
          }
        end

        if removed_line and not added_line then
          lnum_changes_len = lnum_changes_len + 1
          lnum_changes[lnum_changes_len] = {
            lnum = out_lnum,
            buftype = 'current',
            type = 'void',
          }
        end
      end

      if #removed_lines > #added_lines then
        marks[marks_len].bot = bot + (#removed_lines - #added_lines)
      else
        marks[marks_len].bot = bot
      end
    end
  end

  -- Copy remaining original lines after the last hunk
  for k = src_pos, lines_len do
    current_len = current_len + 1
    current_lines[current_len] = lines[k]
    previous_len = previous_len + 1
    previous_lines[previous_len] = lines[k]
  end

  return utils.object.extend(self, {
    current_lines = current_lines,
    previous_lines = previous_lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = marks,
    stat = stat,
  })
end

function Diff:generate(hunks, lines, shape, opts)
  if not shape then return error('shape is required') end

  opts = opts or {}
  local conflicts = opts.conflicts
  local is_deleted = opts.is_deleted

  if shape == 'split' then
    if conflicts then return self:generate_split_conflict(conflicts, lines) end
    if is_deleted then return self:generate_split_deleted(hunks, lines) end
    return self:generate_split(hunks, lines)
  end
  if shape == 'unified' then
    if conflicts then return self:generate_unified_conflict(conflicts, lines) end
    if is_deleted then return self:generate_unified_deleted(hunks, lines) end
    return self:generate_unified(hunks, lines)
  end

  error('shape provided must have values either "unified" or "split')
end

return Diff
