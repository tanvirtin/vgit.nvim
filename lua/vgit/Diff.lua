local CodeDTO = require('vgit.core.CodeDTO')
local Object = require('vgit.core.Object')
local dmp = require('vgit.vendor.dmp')

local Diff = Object:extend()

function Diff:new(hunks)
  return setmetatable({
    hunks = hunks,
    max_lines = 4,
  }, Diff)
end

function Diff:deleted_unified(lines)
  local hunks = self.hunks
  local hunk = hunks[1]
  local type = hunk.type
  local diff = hunk.diff
  local top = hunk.top
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
  return CodeDTO:new({
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

function Diff:deleted_split(lines)
  local hunks = self.hunks
  local hunk = hunks[1]
  local type = hunk.type
  local diff = hunk.diff
  local top = hunk.top
  local bot = hunk.bot
  local lnum_changes = {}
  local s = top
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
  return CodeDTO:new({
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

function Diff:unified(lines)
  local hunks = self.hunks
  if #hunks == 0 then
    return CodeDTO:new({
      lines = lines,
      hunks = hunks,
    })
  end
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
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
      }
      for j = top, bot do
        lnum_changes[#lnum_changes + 1] = {
          lnum = j,
          type = 'add',
          buftype = 'current',
        }
      end
    elseif type == 'remove' then
      marks[#marks + 1] = {
        type = type,
        top = top + 1,
        bot = nil,
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
      }
      local s = top
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
      marks[#marks] = marks[#marks]
    elseif type == 'change' then
      local removed_lines, added_lines = hunk:parse_diff()
      marks[#marks + 1] = {
        type = type,
        top = top,
        bot = nil,
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
      }
      local s = top
      for j = 1, #diff do
        local line = diff[j]
        local cleaned_line = line:sub(2, #line)
        local line_type = line:sub(1, 1)
        if line_type == '-' then
          new_lines_added = new_lines_added + 1
          table.insert(new_lines, s, cleaned_line)
          local word_diff = nil
          if
            #removed_lines == #added_lines
            and #added_lines < self.max_lines
          then
            local d = dmp.diff_main(
              cleaned_line,
              diff[#removed_lines + j]:sub(2, #diff[#removed_lines + j])
            )
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
          if
            #removed_lines == #added_lines
            and #added_lines < self.max_lines
          then
            local d = dmp.diff_main(
              cleaned_line,
              diff[j - #removed_lines]:sub(2, #diff[j - #removed_lines])
            )
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
      marks[#marks] = marks[#marks]
    end
  end
  return CodeDTO:new({
    lines = new_lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = marks,
    stat = stat,
  })
end

function Diff:split(lines)
  local hunks = self.hunks
  if #hunks == 0 then
    return CodeDTO:new({
      current_lines = lines,
      previous_lines = lines,
      hunks = hunks,
    })
  end
  local current_lines = {}
  local previous_lines = {}
  local lnum_changes = {}
  local void_line = ''
  local marks = {}
  local stat = {
    added = 0,
    removed = 0,
  }
  -- shallow copy
  for key, value in pairs(lines) do
    current_lines[key] = value
    previous_lines[key] = value
  end
  -- Operations below will potentially add more lines to both current and
  -- previous data, which means, the offset needs to be added to our hunks.
  local new_lines_added = 0
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
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
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
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
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
      marks[#marks] = marks[#marks]
    elseif type == 'change' then
      marks[#marks + 1] = {
        type = type,
        top = top,
        bot = nil,
        top_lnum = top - new_lines_added,
        bot_lnum = bot - new_lines_added,
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
          if
            #removed_lines == #added_lines
            and #added_lines < self.max_lines
          then
            local d = dmp.diff_main(
              removed_line,
              added_lines[recalculated_index]
            )
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
          if
            #removed_lines == #added_lines
            and #added_lines < self.max_lines
          then
            local d = dmp.diff_main(
              added_line,
              removed_lines[recalculated_index]
            )
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
      marks[#marks] = marks[#marks]
    end
  end
  return CodeDTO:new({
    current_lines = current_lines,
    previous_lines = previous_lines,
    lnum_changes = lnum_changes,
    hunks = hunks,
    marks = marks,
    stat = stat,
  })
end

return Diff
