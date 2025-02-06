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
  local lnum_changes = {}

  for i = 1, #conflicts do
    local conflict = conflicts[i]
    local current = conflict.current
    local ancestor = conflict.ancestor
    local middle = conflict.middle
    local incoming = conflict.incoming

    local top = current.top
    local bot = incoming.bot

    marks[#marks + 1] = {
      type = type,
      top = top,
      bot = bot,
      top_relative = top,
      bot_relative = bot,
    }

    lnum_changes[#lnum_changes + 1] = {
      lnum = current.top,
      buftype = 'current',
      type = 'conflict_current_mark',
    }

    for lnum = current.top + 1, current.bot do
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_current',
      }
    end

    if ancestor and not utils.list.is_empty(ancestor) then
      lnum_changes[#lnum_changes + 1] = {
        lnum = ancestor.top,
        buftype = 'current',
        type = 'conflict_ancestor_mark',
      }
      for lnum = ancestor.top + 1, ancestor.bot do
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
    end

    for lnum = incoming.top, incoming.bot - 1 do
      lnum_changes[#lnum_changes + 1] = {
        lnum = lnum,
        buftype = 'current',
        type = 'conflict_incoming',
      }
    end

    lnum_changes[#lnum_changes + 1] = {
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
      type = type,
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

  local new_lines = {}
  local lnum_changes = {}
  local marks = {}
  local stat = {
    added = 0,
    removed = 0,
  }

  for key, value in pairs(lines) do
    new_lines[key] = value
  end

  local new_lines_added = 0

  for i = 1, #hunks do
    local hunk = hunks[i]
    local type = hunk.type
    local diff = hunk.diff
    local top = hunk.top + new_lines_added
    local bot = hunk.bot + new_lines_added
    local hunk_stat = hunk.stat

    stat.added = stat.added + hunk_stat.added
    stat.removed = stat.removed + hunk_stat.removed

    if type == 'add' then
      marks[#marks + 1] = {
        type = type,
        top = top,
        bot = bot,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = top, bot do
        lnum_changes[#lnum_changes + 1] = {
          lnum = j,
          type = 'add',
          buftype = 'current',
        }
      end
    elseif type == 'remove' then
      local s = top

      marks[#marks + 1] = {
        type = type,
        top = top + 1,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = 1, #diff do
        local line = diff[j]
        s = s + 1
        new_lines_added = new_lines_added + 1
        table.insert(new_lines, s, line:sub(2, #line))
        lnum_changes[#lnum_changes + 1] = {
          lnum = s,
          type = 'remove',
          buftype = 'current',
        }
      end

      marks[#marks].bot = top + #diff
    elseif type == 'change' then
      local removed_lines, added_lines = hunk:parse_diff()
      local s = top

      marks[#marks + 1] = {
        type = type,
        top = top,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = 1, #diff do
        local line = diff[j]
        local cleaned_line = line:sub(2, #line)
        local line_type = line:sub(1, 1)

        if line_type == '-' then
          local word_diff = nil

          new_lines_added = new_lines_added + 1
          table.insert(new_lines, s, cleaned_line)

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(cleaned_line, diff[#removed_lines + j]:sub(2, #diff[#removed_lines + j]))
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes[#lnum_changes + 1] = {
            lnum = s,
            type = 'remove',
            buftype = 'current',
            word_diff = word_diff,
          }
        elseif line_type == '+' then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(cleaned_line, diff[j - #removed_lines]:sub(2, #diff[j - #removed_lines]))
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes[#lnum_changes + 1] = {
            lnum = s,
            type = 'add',
            buftype = 'current',
            word_diff = word_diff,
          }
        end

        s = s + 1
      end

      marks[#marks].bot = top + #diff - 1
    end
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

  -- Operations below will potentially add more lines to both current and
  -- previous data, which means, the offset needs to be added to our hunks.
  local new_lines_added = 0
  local current_lines = {}
  local previous_lines = {}
  local lnum_changes = {}
  local void_line = ''
  local marks = {}
  local stat = {
    added = 0,
    removed = 0,
  }

  for key, value in pairs(lines) do
    previous_lines[key] = value
    current_lines[key] = value
  end

  for i = 1, #hunks do
    local hunk = hunks[i]
    local type = hunk.type
    local top = hunk.top + new_lines_added
    local bot = hunk.bot + new_lines_added
    local diff = hunk.diff
    local hunk_stat = hunk.stat

    stat.added = stat.added + hunk_stat.added
    stat.removed = stat.removed + hunk_stat.removed

    if type == 'add' then
      marks[#marks + 1] = {
        type = type,
        top = top,
        bot = bot,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      -- Remove the line indicating that these lines were inserted in current_lines.
      for j = top, bot do
        previous_lines[j] = void_line
        lnum_changes[#lnum_changes + 1] = {
          lnum = j,
          buftype = 'previous',
          type = 'void',
        }
        lnum_changes[#lnum_changes + 1] = {
          lnum = j,
          buftype = 'current',
          type = 'add',
        }
      end
    elseif type == 'remove' then
      local current_new_lines_added = 0

      marks[#marks + 1] = {
        type = type,
        top = top + 1,
        bot = nil,
        top_relative = top - new_lines_added,
        bot_relative = bot - new_lines_added,
      }

      for j = 1, #diff do
        local line = diff[j]

        top = top + 1
        current_new_lines_added = current_new_lines_added + 1

        table.insert(current_lines, top, void_line)
        table.insert(previous_lines, top, line:sub(2, #line))

        lnum_changes[#lnum_changes + 1] = {
          lnum = top,
          buftype = 'current',
          type = 'void',
        }
        lnum_changes[#lnum_changes + 1] = {
          lnum = top,
          buftype = 'previous',
          type = 'remove',
        }
      end

      new_lines_added = new_lines_added + current_new_lines_added
      marks[#marks].bot = bot + current_new_lines_added
    elseif type == 'change' then
      marks[#marks + 1] = {
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
      -- Hunk bot index does not indicate the total number of lines that may have a diff.
      -- Which is why I am inserting empty lines into both the current and previous data arrays.
      for j = bot + 1, (top + max_lines) - 1 do
        new_lines_added = new_lines_added + 1
        table.insert(current_lines, j, void_line)
        table.insert(previous_lines, j, void_line)
      end
      -- With the new calculated range I simply loop over and add the removed
      -- and added lines to their corresponding arrays that contain a buffer lines.
      for j = top, top + max_lines - 1 do
        local recalculated_index = (j - top) + 1
        local added_line = added_lines[recalculated_index]
        local removed_line = removed_lines[recalculated_index]

        if removed_line then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(removed_line, added_lines[recalculated_index])
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes[#lnum_changes + 1] = {
            lnum = j,
            buftype = 'previous',
            type = 'remove',
            word_diff = word_diff,
          }
        end

        if added_line then
          local word_diff = nil

          if #removed_lines == #added_lines and #added_lines < MAX_LINES then
            local d = dmp.diff_main(added_line, removed_lines[recalculated_index])
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end

          lnum_changes[#lnum_changes + 1] = {
            lnum = j,
            buftype = 'current',
            type = 'add',
            word_diff = word_diff,
          }
        end

        if added_line and not removed_line then
          lnum_changes[#lnum_changes + 1] = {
            lnum = j,
            buftype = 'previous',
            type = 'void',
          }
        end

        if removed_line and not added_line then
          lnum_changes[#lnum_changes + 1] = {
            lnum = j,
            buftype = 'current',
            type = 'void',
          }
        end

        previous_lines[j] = removed_line or void_line
        current_lines[j] = added_line or void_line
      end

      if #removed_lines > #added_lines then
        marks[#marks].bot = bot + (#removed_lines - #added_lines)
      else
        marks[#marks].bot = bot
      end
    end
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
