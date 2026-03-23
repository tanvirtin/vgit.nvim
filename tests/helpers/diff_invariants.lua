local M = {}

local function fail(msg)
  error(msg, 3)
end

function M.assert_marks_ascending(marks)
  for i = 2, #marks do
    if marks[i].top <= marks[i - 1].bot then
      fail(string.format('marks[%d].top (%d) should be > marks[%d].bot (%d)', i, marks[i].top, i - 1, marks[i - 1].bot))
    end
  end
end

function M.assert_marks_within_bounds(marks, line_count)
  for i, mark in ipairs(marks) do
    if mark.top < 1 then fail(string.format('marks[%d].top = %d < 1', i, mark.top)) end
    if mark.bot > line_count then fail(string.format('marks[%d].bot = %d > %d lines', i, mark.bot, line_count)) end
    if mark.top > mark.bot then fail(string.format('marks[%d].top = %d > bot = %d', i, mark.top, mark.bot)) end
  end
end

function M.assert_lnum_changes_within_bounds(lnum_changes, line_count)
  for i, lc in ipairs(lnum_changes) do
    if lc.lnum < 1 then fail(string.format('lnum_changes[%d].lnum = %d < 1', i, lc.lnum)) end
    if lc.lnum > line_count then
      fail(string.format('lnum_changes[%d].lnum = %d > %d lines', i, lc.lnum, line_count))
    end
  end
end

function M.assert_word_diff_shape(lnum_changes)
  for i, lc in ipairs(lnum_changes) do
    if lc.word_diff then
      if type(lc.word_diff) ~= 'table' then fail(string.format('lnum_changes[%d].word_diff should be a table', i)) end
      for j, seg in ipairs(lc.word_diff) do
        if #seg ~= 2 then
          fail(string.format('lnum_changes[%d].word_diff[%d] should be {op, text}, got %d elements', i, j, #seg))
        end
        if seg[1] ~= -1 and seg[1] ~= 0 and seg[1] ~= 1 then
          fail(string.format('lnum_changes[%d].word_diff[%d][1] = %s, expected -1, 0, or 1', i, j, tostring(seg[1])))
        end
        if type(seg[2]) ~= 'string' then
          fail(string.format('lnum_changes[%d].word_diff[%d][2] should be string, got %s', i, j, type(seg[2])))
        end
      end
    end
  end
end

function M.assert_stat_consistency(stat, lnum_changes)
  local add_count = 0
  local remove_count = 0
  for _, lc in ipairs(lnum_changes) do
    if lc.type == 'add' then
      add_count = add_count + 1
    elseif lc.type == 'remove' then
      remove_count = remove_count + 1
    end
  end
  if stat.added ~= add_count then fail(string.format('stat.added (%d) != add count (%d)', stat.added, add_count)) end
  if stat.removed ~= remove_count then
    fail(string.format('stat.removed (%d) != remove count (%d)', stat.removed, remove_count))
  end
end

function M.assert_split_equal_length(result)
  if #result.current_lines ~= #result.previous_lines then
    fail(string.format('current_lines (%d) != previous_lines (%d)', #result.current_lines, #result.previous_lines))
  end
end

function M.assert_split_buftype_present(lnum_changes)
  for i, lc in ipairs(lnum_changes) do
    if lc.buftype ~= 'current' and lc.buftype ~= 'previous' then
      fail(string.format('lnum_changes[%d].buftype = %s, expected current/previous', i, tostring(lc.buftype)))
    end
  end
end

function M.assert_unified_diff(result)
  if not result.lines then fail('unified diff should have lines') end
  if not result.marks then fail('unified diff should have marks') end
  if not result.lnum_changes then fail('unified diff should have lnum_changes') end
  if not result.stat then fail('unified diff should have stat') end
  M.assert_marks_ascending(result.marks)
  M.assert_marks_within_bounds(result.marks, #result.lines)
  M.assert_lnum_changes_within_bounds(result.lnum_changes, #result.lines)
  M.assert_word_diff_shape(result.lnum_changes)
  M.assert_stat_consistency(result.stat, result.lnum_changes)
end

function M.assert_split_diff(result)
  if not result.current_lines then fail('split diff should have current_lines') end
  if not result.previous_lines then fail('split diff should have previous_lines') end
  if not result.marks then fail('split diff should have marks') end
  if not result.lnum_changes then fail('split diff should have lnum_changes') end
  if not result.stat then fail('split diff should have stat') end
  M.assert_split_equal_length(result)
  M.assert_marks_ascending(result.marks)
  M.assert_marks_within_bounds(result.marks, #result.current_lines)
  M.assert_lnum_changes_within_bounds(result.lnum_changes, #result.current_lines)
  M.assert_split_buftype_present(result.lnum_changes)
  M.assert_word_diff_shape(result.lnum_changes)
  M.assert_stat_consistency(result.stat, result.lnum_changes)
end

function M.assert_patch_marks(marks, total_lines)
  M.assert_marks_ascending(marks)
  M.assert_marks_within_bounds(marks, total_lines)
end

return M
