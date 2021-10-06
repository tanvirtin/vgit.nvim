local utils = require('vgit.utils')
local dmp = require('vgit.lib.dmp')
local scheduler = require('plenary.async.util').scheduler

local M = {}

M.constants = utils.readonly({ word_diff_max_lines = 4 })

local function create_change(opts)
  opts = opts or {}
  return {
    lines = opts.lines or {},
    current_lines = opts.current_lines or {},
    previous_lines = opts.previous_lines or {},
    lnum_changes = opts.lnum_changes or {},
    hunks = opts.hunks or {},
    marks = opts.marks or {},
  }
end

M.horizontal = function(lines, hunks)
  if #hunks == 0 then
    return utils.readonly(create_change({
      lines = lines,
      hunks = hunks,
    }))
  end
  local new_lines = {}
  local lnum_changes = {}
  local marks = {}
  for key, value in pairs(lines) do
    scheduler()
    new_lines[key] = value
  end
  local new_lines_added = 0
  for i = 1, #hunks do
    scheduler()
    local hunk = hunks[i]
    local type = hunk.type
    local diff = hunk.diff
    local start = hunk.start + new_lines_added
    local finish = hunk.finish + new_lines_added
    if type == 'add' then
      marks[#marks + 1] = utils.readonly({
        type = type,
        start = start,
        finish = finish,
      })
      for j = start, finish do
        scheduler()
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = j,
          type = 'add',
        })
      end
    elseif type == 'remove' then
      marks[#marks + 1] = {
        type = type,
        start = start + 1,
        finish = nil,
      }
      local s = start
      for j = 1, #diff do
        scheduler()
        local line = diff[j]
        s = s + 1
        new_lines_added = new_lines_added + 1
        table.insert(new_lines, s, line:sub(2, #line))
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = s,
          type = 'remove',
        })
      end
      marks[#marks].finish = start + #diff
      marks[#marks] = utils.readonly(marks[#marks])
    elseif type == 'change' then
      local removed_lines, added_lines = hunk:parse_diff()
      marks[#marks + 1] = {
        type = type,
        start = start,
        finish = nil,
      }
      local s = start
      for j = 1, #diff do
        scheduler()
        local line = diff[j]
        local cleaned_line = line:sub(2, #line)
        local line_type = line:sub(1, 1)
        if line_type == '-' then
          new_lines_added = new_lines_added + 1
          table.insert(new_lines, s, cleaned_line)
          local word_diff = nil
          if
            #removed_lines == #added_lines
            and #added_lines < M.constants.word_diff_max_lines
          then
            local d = dmp.diff_main(
              cleaned_line,
              diff[#removed_lines + j]:sub(2, #diff[#removed_lines + j])
            )
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = s,
            type = 'remove',
            word_diff = word_diff,
          })
        elseif line_type == '+' then
          local word_diff = nil
          if
            #removed_lines == #added_lines
            and #added_lines < M.constants.word_diff_max_lines
          then
            local d = dmp.diff_main(
              cleaned_line,
              diff[j - #removed_lines]:sub(2, #diff[j - #removed_lines])
            )
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = s,
            type = 'add',
            word_diff = word_diff,
          })
        end
        s = s + 1
      end
      marks[#marks].finish = start + #diff - 1
      marks[#marks] = utils.readonly(marks[#marks])
    end
  end
  return utils.readonly(create_change({
    lines = new_lines,
    hunks = hunks,
    lnum_changes = lnum_changes,
    marks = marks,
  }))
end

M.vertical = function(lines, hunks)
  if #hunks == 0 then
    return utils.readonly(create_change({
      current_lines = lines,
      previous_lines = lines,
      hunks = hunks,
    }))
  end
  local current_lines = {}
  local previous_lines = {}
  local lnum_changes = {}
  local void_line = ''
  local marks = {}
  -- shallow copy
  for key, value in pairs(lines) do
    scheduler()
    current_lines[key] = value
    previous_lines[key] = value
  end
  -- Operations below will potentially add more lines to both current and
  -- previous data, which means, the offset needs to be added to our hunks.
  local new_lines_added = 0
  for i = 1, #hunks do
    scheduler()
    local hunk = hunks[i]
    local type = hunk.type
    local start = hunk.start + new_lines_added
    local finish = hunk.finish + new_lines_added
    local diff = hunk.diff
    if type == 'add' then
      marks[#marks + 1] = utils.readonly({
        type = type,
        start = start,
        finish = finish,
      })
      -- Remove the line indicating that these lines were inserted in current_lines.
      for j = start, finish do
        scheduler()
        previous_lines[j] = void_line
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = j,
          buftype = 'previous',
          type = 'void',
        })
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = j,
          buftype = 'current',
          type = 'add',
        })
      end
    elseif type == 'remove' then
      local current_new_lines_added = 0
      marks[#marks + 1] = {
        type = type,
        start = start + 1,
        finish = nil,
      }
      for j = 1, #diff do
        scheduler()
        local line = diff[j]
        start = start + 1
        current_new_lines_added = current_new_lines_added + 1
        table.insert(current_lines, start, void_line)
        table.insert(previous_lines, start, line:sub(2, #line))
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = start,
          buftype = 'current',
          type = 'void',
        })
        lnum_changes[#lnum_changes + 1] = utils.readonly({
          lnum = start,
          buftype = 'previous',
          type = 'remove',
        })
      end
      new_lines_added = new_lines_added + current_new_lines_added
      marks[#marks].finish = finish + current_new_lines_added
      marks[#marks] = utils.readonly(marks[#marks])
    elseif type == 'change' then
      marks[#marks + 1] = {
        type = type,
        start = start,
        finish = nil,
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
      -- Hunk finish index does not indicate the total number of lines that may have a diff.
      -- Which is why I am inserting empty lines into both the current and previous data arrays.
      for j = finish + 1, (start + max_lines) - 1 do
        scheduler()
        new_lines_added = new_lines_added + 1
        table.insert(current_lines, j, void_line)
        table.insert(previous_lines, j, void_line)
      end
      -- With the new calculated range I simply loop over and add the removed
      -- and added lines to their corresponding arrays that contain a buffer lines.
      for j = start, start + max_lines - 1 do
        scheduler()
        local recalculated_index = (j - start) + 1
        local added_line = added_lines[recalculated_index]
        local removed_line = removed_lines[recalculated_index]
        if removed_line then
          local word_diff = nil
          if
            #removed_lines == #added_lines
            and #added_lines < M.constants.word_diff_max_lines
          then
            local d = dmp.diff_main(
              removed_line,
              added_lines[recalculated_index]
            )
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = j,
            buftype = 'previous',
            type = 'remove',
            word_diff = word_diff,
          })
        end
        if added_line then
          local word_diff = nil
          if
            #removed_lines == #added_lines
            and #added_lines < M.constants.word_diff_max_lines
          then
            local d = dmp.diff_main(
              added_line,
              removed_lines[recalculated_index]
            )
            dmp.diff_cleanupSemantic(d)
            word_diff = d
          end
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = j,
            buftype = 'current',
            type = 'add',
            word_diff = word_diff,
          })
        end
        if added_line and not removed_line then
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = j,
            buftype = 'previous',
            type = 'void',
          })
        end
        if removed_line and not added_line then
          lnum_changes[#lnum_changes + 1] = utils.readonly({
            lnum = j,
            buftype = 'current',
            type = 'void',
          })
        end
        previous_lines[j] = removed_line or void_line
        current_lines[j] = added_line or void_line
      end
      if #removed_lines > #added_lines then
        marks[#marks].finish = finish + (#removed_lines - #added_lines)
      else
        marks[#marks].finish = finish
      end
      marks[#marks] = utils.readonly(marks[#marks])
    end
  end
  return utils.readonly(create_change({
    current_lines = current_lines,
    previous_lines = previous_lines,
    hunks = hunks,
    lnum_changes = lnum_changes,
    marks = marks,
  }))
end

return M
