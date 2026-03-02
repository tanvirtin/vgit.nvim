local Diff = require('vgit.core.diff.Diff')
local GitHunk = require('vgit.git.GitHunk')

local eq = assert.are.same

-- Helper to create a hunk with diff lines
local function make_hunk(header, diff_lines)
  local hunk = GitHunk(header)
  for _, line in ipairs(diff_lines or {}) do
    hunk:push(line)
  end
  return hunk
end

describe('Diff:', function()
  describe('constructor', function()
    it('should set defaults', function()
      local diff = Diff()
      eq({}, diff.hunks)
      eq({}, diff.marks)
      eq({}, diff.lines)
      eq({}, diff.lnum_changes)
      eq({ added = 0, removed = 0 }, diff.stat)
    end)

    it('should accept opts', function()
      local diff = Diff({ stat = { added = 5, removed = 3 } })
      assert.are.equal(5, diff.stat.added)
    end)
  end)

  describe('generate', function()
    it('should error when shape is nil', function()
      local diff = Diff()
      assert.has_error(function()
        diff:generate({}, {}, nil)
      end)
    end)

    it('should error on invalid shape', function()
      local diff = Diff()
      assert.has_error(function()
        diff:generate({}, {}, 'invalid')
      end)
    end)

    it('should dispatch to unified', function()
      local diff = Diff()
      local lines = { 'line1', 'line2' }
      local result = diff:generate({}, lines, 'unified')
      eq(lines, result.lines)
    end)

    it('should dispatch to split', function()
      local diff = Diff()
      local lines = { 'line1', 'line2' }
      local result = diff:generate({}, lines, 'split')
      eq(lines, result.current_lines)
      eq(lines, result.previous_lines)
    end)

    it('should dispatch to unified_deleted when is_deleted', function()
      local diff = Diff()
      local lines = { 'old1', 'old2' }
      local result = diff:generate({}, lines, 'unified', { is_deleted = true })
      eq(lines, result.lines)
    end)

    it('should dispatch to split_deleted when is_deleted', function()
      local diff = Diff()
      local lines = { 'old1', 'old2' }
      local result = diff:generate({}, lines, 'split', { is_deleted = true })
      eq(lines, result.previous_lines)
    end)
  end)

  describe('generate_unified', function()
    it('should return lines unchanged when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b', 'c' }
      local result = diff:generate_unified({}, lines)
      eq(lines, result.lines)
      eq({}, result.hunks)
    end)

    it('should handle add hunk', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local lines = { 'new1', 'new2' }
      local result = diff:generate_unified({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal('add', result.marks[1].type)
      assert.are.equal(1, result.marks[1].top)
      assert.are.equal(2, result.marks[1].bot)
      assert.are.equal(2, result.stat.added)
      assert.are.equal(0, result.stat.removed)

      -- lnum_changes should mark both lines as add
      local add_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'add' then add_count = add_count + 1 end
      end
      assert.are.equal(2, add_count)
    end)

    it('should handle remove hunk by inserting lines', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c', 'd' }
      local result = diff:generate_unified({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal('remove', result.marks[1].type)
      assert.are.equal(0, result.stat.added)
      assert.are.equal(2, result.stat.removed)

      -- Lines should have the removed lines inserted
      assert.are.equal(6, #result.lines) -- 4 original + 2 inserted
    end)

    it('should handle change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local lines = { 'a', 'new', 'c' }
      local result = diff:generate_unified({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal('change', result.marks[1].type)
      assert.are.equal(1, result.stat.added)
      assert.are.equal(1, result.stat.removed)
    end)

    it('should accumulate stats from multiple hunks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -0,0 +3,1 @@', { '+another' })
      local diff = Diff()
      local lines = { 'added', 'middle', 'another' }
      local result = diff:generate_unified({ hunk1, hunk2 }, lines)

      assert.are.equal(2, result.stat.added)
      assert.are.equal(0, result.stat.removed)
      assert.are.equal(2, #result.marks)
    end)

    it('should set top_relative and bot_relative on marks', function()
      local hunk = make_hunk('@@ -0,0 +2,3 @@', { '+a', '+b', '+c' })
      local diff = Diff()
      local lines = { 'x', 'a', 'b', 'c' }
      local result = diff:generate_unified({ hunk }, lines)

      assert.is_not_nil(result.marks[1].top_relative)
      assert.is_not_nil(result.marks[1].bot_relative)
    end)

    it('should insert removed line content with the dash prefix stripped', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c', 'd' }
      local result = diff:generate_unified({ hunk }, lines)

      local found = {}
      for _, line in ipairs(result.lines) do
        found[line] = true
      end
      assert.is_true(found['removed1'])
      assert.is_true(found['removed2'])
      assert.is_nil(found['-removed1'])
      assert.is_nil(found['-removed2'])
    end)
  end)

  describe('generate_split', function()
    it('should return lines in both sides when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_split({}, lines)
      eq(lines, result.current_lines)
      eq(lines, result.previous_lines)
      assert.are.equal(#result.current_lines, #result.previous_lines)
    end)

    it('should handle add hunk with void in previous', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local lines = { 'new1', 'new2' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(1, #result.marks)
      assert.are.equal('add', result.marks[1].type)

      -- Previous lines should have void (empty string) where adds are
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' and lc.buftype == 'previous' then void_count = void_count + 1 end
      end
      assert.are.equal(2, void_count)
    end)

    it('should handle remove hunk with void in current', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c', 'd' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(1, #result.marks)
      assert.are.equal('remove', result.marks[1].type)

      -- Current lines should have void where removes are
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' and lc.buftype == 'current' then void_count = void_count + 1 end
      end
      assert.are.equal(2, void_count)
    end)

    it('should handle change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local lines = { 'a', 'new', 'c' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(1, #result.marks)
      assert.are.equal('change', result.marks[1].type)

      -- Should have both add and remove lnum_changes
      local has_add = false
      local has_remove = false
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'add' and lc.buftype == 'current' then has_add = true end
        if lc.type == 'remove' and lc.buftype == 'previous' then has_remove = true end
      end
      assert.is_true(has_add)
      assert.is_true(has_remove)
    end)

    it('should handle change hunk with unequal added/removed lines', function()
      -- 1 line removed, 3 lines added — max_lines = 3, must pad
      local hunk = make_hunk('@@ -2,1 +2,3 @@', { '-old', '+new1', '+new2', '+new3' })
      local diff = Diff()
      local lines = { 'a', 'new1', 'new2', 'new3', 'c' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
    end)

    it('should accumulate stats from multiple hunks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -0,0 +3,1 @@', { '+another' })
      local diff = Diff()
      local lines = { 'added', 'middle', 'another' }
      local result = diff:generate_split({ hunk1, hunk2 }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(2, result.stat.added)
      assert.are.equal(2, #result.marks)
    end)

    it('should maintain equal line count with mixed hunk types', function()
      local hunk1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local hunk2 = make_hunk('@@ -4,2 +6,0 @@', { '-removed1', '-removed2' })
      local hunk3 = make_hunk('@@ -7,1 +7,2 @@', { '-old', '+changed1', '+changed2' })
      local diff = Diff()
      local lines = { 'new1', 'new2', 'a', 'b', 'c', 'd', 'changed1', 'changed2' }
      local result = diff:generate_split({ hunk1, hunk2, hunk3 }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
    end)

    it('should maintain equal line count with large add hunk', function()
      local diff_lines = {}
      local lines = {}
      for i = 1, 50 do
        diff_lines[i] = '+line' .. i
        lines[i] = 'line' .. i
      end
      local hunk = make_hunk('@@ -0,0 +1,50 @@', diff_lines)
      local diff = Diff()
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(50, #result.current_lines)
    end)

    it('should maintain equal line count with large remove hunk', function()
      local diff_lines = {}
      for i = 1, 30 do
        diff_lines[i] = '-removed' .. i
      end
      local hunk = make_hunk('@@ -3,30 +3,0 @@', diff_lines)
      local diff = Diff()
      local lines = { 'a', 'b', 'c' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
    end)

    it('should place added content in current_lines and empty strings in previous_lines', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local lines = { 'new1', 'new2' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal('new1', result.current_lines[1])
      assert.are.equal('new2', result.current_lines[2])
      assert.are.equal('', result.previous_lines[1])
      assert.are.equal('', result.previous_lines[2])
    end)

    it('should place removed content in previous_lines and empty strings in current_lines', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c', 'd' }
      local result = diff:generate_split({ hunk }, lines)

      local prev_found = {}
      for _, line in ipairs(result.previous_lines) do
        prev_found[line] = true
      end
      assert.is_true(prev_found['removed1'])
      assert.is_true(prev_found['removed2'])

      -- Those same positions in current_lines should be blank (void)
      local blank_count = 0
      for _, line in ipairs(result.current_lines) do
        if line == '' then blank_count = blank_count + 1 end
      end
      assert.is_true(blank_count >= 2)
    end)

    it('should place old content in previous_lines and new content in current_lines for change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local lines = { 'a', 'new', 'c' }
      local result = diff:generate_split({ hunk }, lines)

      -- Changed line: previous shows the removed content, current shows the added content
      assert.are.equal('old', result.previous_lines[2])
      assert.are.equal('new', result.current_lines[2])

      -- Context lines are identical on both sides
      assert.are.equal('a', result.previous_lines[1])
      assert.are.equal('a', result.current_lines[1])
      assert.are.equal('c', result.previous_lines[3])
      assert.are.equal('c', result.current_lines[3])
    end)
  end)

  describe('generate_unified_deleted', function()
    it('should return lines unchanged when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_unified_deleted({}, lines)
      eq(lines, result.lines)
    end)

    it('should mark all lines as remove', function()
      local hunk = make_hunk('@@ -1,3 +0,0 @@', { '-a', '-b', '-c' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c' }
      local result = diff:generate_unified_deleted({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal(1, result.marks[1].top)

      -- All lnum_changes should be remove
      for _, lc in ipairs(result.lnum_changes) do
        assert.are.equal('remove', lc.type)
      end
      assert.are.equal(3, #result.lnum_changes)
    end)

    it('should carry hunk stat', function()
      local hunk = make_hunk('@@ -1,2 +0,0 @@', { '-x', '-y' })
      local diff = Diff()
      local result = diff:generate_unified_deleted({ hunk }, { 'x', 'y' })
      assert.are.equal(0, result.stat.added)
      assert.are.equal(2, result.stat.removed)
    end)
  end)

  describe('generate_split_deleted', function()
    it('should return empty current_lines when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_split_deleted({}, lines)
      eq(lines, result.previous_lines)
      eq({}, result.current_lines)
    end)

    it('should mark previous as remove and current as void', function()
      local hunk = make_hunk('@@ -1,2 +0,0 @@', { '-a', '-b' })
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_split_deleted({ hunk }, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)

      local remove_count = 0
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'remove' and lc.buftype == 'previous' then remove_count = remove_count + 1 end
        if lc.type == 'void' and lc.buftype == 'current' then void_count = void_count + 1 end
      end
      assert.are.equal(2, remove_count)
      assert.are.equal(2, void_count)
    end)

    it('should create empty current_lines entries', function()
      local hunk = make_hunk('@@ -1,3 +0,0 @@', { '-a', '-b', '-c' })
      local diff = Diff()
      local result = diff:generate_split_deleted({ hunk }, { 'a', 'b', 'c' })
      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(3, #result.current_lines)
      for _, line in ipairs(result.current_lines) do
        assert.are.equal('', line)
      end
    end)
  end)

  describe('generate_unified_conflict', function()
    it('should produce marks and lnum_changes for a conflict', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 3 },
          ancestor = nil,
          middle = { top = 4, bot = 4 },
          incoming = { top = 5, bot = 7 },
        },
      }
      local lines = { '<<<', 'cur1', 'cur2', '===', 'inc1', 'inc2', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal(1, result.marks[1].top)
      assert.are.equal(7, result.marks[1].bot)
      assert.are.equal('conflict', result.marks[1].type)

      -- Should have conflict_current_mark, conflict_current, conflict_middle, conflict_incoming, conflict_incoming_mark
      local types = {}
      for _, lc in ipairs(result.lnum_changes) do
        types[lc.type] = (types[lc.type] or 0) + 1
      end
      assert.is_not_nil(types.conflict_current_mark)
      assert.is_not_nil(types.conflict_current)
      assert.is_not_nil(types.conflict_middle)
      assert.is_not_nil(types.conflict_incoming)
      assert.is_not_nil(types.conflict_incoming_mark)
    end)

    it('should handle conflict with ancestor section', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = { top = 3, bot = 4 },
          middle = { top = 5, bot = 5 },
          incoming = { top = 6, bot = 7 },
        },
      }
      local lines = { '<<<', 'c1', '|||', 'anc', '===', 'i1', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      assert.are.equal('conflict', result.marks[1].type)

      local types = {}
      for _, lc in ipairs(result.lnum_changes) do
        types[lc.type] = (types[lc.type] or 0) + 1
      end
      assert.is_not_nil(types.conflict_ancestor_mark)
      assert.is_not_nil(types.conflict_ancestor)
    end)

    it('should handle multiple conflicts', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
        {
          current = { top = 7, bot = 8 },
          ancestor = nil,
          middle = { top = 9, bot = 9 },
          incoming = { top = 10, bot = 11 },
        },
      }
      local lines = { '<<<', 'c1', '===', 'i1', '>>>', 'normal', '<<<', 'c2', '===', 'i2', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      assert.are.equal(2, #result.marks)
      assert.are.equal('conflict', result.marks[1].type)
      assert.are.equal('conflict', result.marks[2].type)
      assert.are.equal(1, result.marks[1].top)
      assert.are.equal(5, result.marks[1].bot)
      assert.are.equal(7, result.marks[2].top)
      assert.are.equal(11, result.marks[2].bot)
    end)

    it('should set stat to zero for conflicts', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
      }
      local lines = { '<<<', 'c', '===', 'i', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      eq({ added = 0, removed = 0 }, result.stat)
    end)

    it('should not modify the lines array', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
      }
      local lines = { '<<<', 'c', '===', 'i', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      eq(lines, result.lines)
    end)

    it('should preserve non-conflict lines between two conflicts', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
        {
          current = { top = 7, bot = 8 },
          ancestor = nil,
          middle = { top = 9, bot = 9 },
          incoming = { top = 10, bot = 11 },
        },
      }
      local lines = { '<<<', 'c1', '===', 'i1', '>>>', 'normal', '<<<', 'c2', '===', 'i2', '>>>' }
      local result = diff:generate_unified_conflict(conflicts, lines)

      -- Line 6 ('normal') sits between the two conflicts and must be untouched
      assert.are.equal('normal', result.lines[6])

      -- No lnum_change should reference line 6
      for _, lc in ipairs(result.lnum_changes) do
        assert.are_not.equal(6, lc.lnum)
      end
    end)
  end)

  describe('generate_split_conflict', function()
    it('should produce marks and lnum_changes for a conflict', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 3 },
          ancestor = nil,
          middle = { top = 4, bot = 4 },
          incoming = { top = 5, bot = 7 },
        },
      }
      local lines = { '<<<', 'cur1', 'cur2', '===', 'inc1', 'inc2', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(1, #result.marks)
      assert.are.equal('conflict', result.marks[1].type)
      assert.is_not_nil(result.previous_lines)
      assert.is_not_nil(result.current_lines)

      -- Should have void entries in the split view
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' then void_count = void_count + 1 end
      end
      assert.is_true(void_count > 0)
    end)

    it('should set mark type to conflict for split conflicts', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = { top = 3, bot = 4 },
          middle = { top = 5, bot = 5 },
          incoming = { top = 6, bot = 7 },
        },
      }
      local lines = { '<<<', 'c1', '|||', 'anc', '===', 'i1', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      assert.are.equal(1, #result.marks)
      assert.are.equal('conflict', result.marks[1].type)
      assert.are.equal(1, result.marks[1].top)
      assert.are.equal(7, result.marks[1].bot)
    end)

    it('should set stat to zero for split conflicts', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
      }
      local lines = { '<<<', 'c', '===', 'i', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      assert.are.equal(#result.current_lines, #result.previous_lines)
      eq({ added = 0, removed = 0 }, result.stat)
    end)

    it('should erase conflict markers and content symmetrically from each panel', function()
      -- current.top (<<<) erased from left; incoming.bot (>>>) erased from right
      -- current content erased from left; incoming content erased from right
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 3 },
          ancestor = nil,
          middle = { top = 4, bot = 4 },
          incoming = { top = 5, bot = 7 },
        },
      }
      local lines = { '<<<', 'cur1', 'cur2', '===', 'inc1', 'inc2', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      -- Left panel: <<<<<<< marker and current content erased
      assert.are.equal('', result.previous_lines[1]) -- current.top
      assert.are.equal('', result.previous_lines[2]) -- current content
      assert.are.equal('', result.previous_lines[3]) -- current content

      -- Right panel: >>>>>>> marker and incoming content erased
      assert.are.equal('', result.current_lines[5]) -- incoming content
      assert.are.equal('', result.current_lines[6]) -- incoming content
      assert.are.equal('', result.current_lines[7]) -- incoming.bot (>>>)

      -- Non-conflict lines untouched on both sides
      assert.are.equal('===', result.previous_lines[4])
      assert.are.equal('===', result.current_lines[4])
    end)

    it('should retain current content on right panel and incoming content on left panel', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 3 },
          ancestor = nil,
          middle = { top = 4, bot = 4 },
          incoming = { top = 5, bot = 7 },
        },
      }
      local lines = { '<<<', 'cur1', 'cur2', '===', 'inc1', 'inc2', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      -- Right panel (current_lines) shows HEAD/current content
      assert.are.equal('cur1', result.current_lines[2])
      assert.are.equal('cur2', result.current_lines[3])

      -- Left panel (previous_lines) shows incoming content
      assert.are.equal('inc1', result.previous_lines[5])
      assert.are.equal('inc2', result.previous_lines[6])
    end)

    it('should emit all conflict lnum_change types with correct buftypes', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 3 },
          ancestor = nil,
          middle = { top = 4, bot = 4 },
          incoming = { top = 5, bot = 7 },
        },
      }
      local lines = { '<<<', 'cur1', 'cur2', '===', 'inc1', 'inc2', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      local seen = {}
      for _, lc in ipairs(result.lnum_changes) do
        seen[lc.type .. ':' .. lc.buftype] = true
      end

      -- Current section signs go on the right (current) panel
      assert.is_true(seen['conflict_current_mark:current'])
      assert.is_true(seen['conflict_current:current'])

      -- Middle separator appears on both panels
      assert.is_true(seen['conflict_middle:current'])
      assert.is_true(seen['conflict_middle:previous'])

      -- Incoming section signs go on the left (previous) panel
      assert.is_true(seen['conflict_incoming:previous'])
      assert.is_true(seen['conflict_incoming_mark:previous'])
    end)

    it('should generate ancestor marks on both panels', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = { top = 3, bot = 4 },
          middle = { top = 5, bot = 5 },
          incoming = { top = 6, bot = 7 },
        },
      }
      local lines = { '<<<', 'c1', '|||', 'anc', '===', 'i1', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      local seen = {}
      for _, lc in ipairs(result.lnum_changes) do
        seen[lc.type .. ':' .. lc.buftype] = true
      end

      assert.is_true(seen['conflict_ancestor_mark:previous'])
      assert.is_true(seen['conflict_ancestor_mark:current'])
      assert.is_true(seen['conflict_ancestor:previous'])
      assert.is_true(seen['conflict_ancestor:current'])
    end)

    it('should handle multiple conflicts with non-conflict lines untouched on both panels', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
        {
          current = { top = 7, bot = 8 },
          ancestor = nil,
          middle = { top = 9, bot = 9 },
          incoming = { top = 10, bot = 11 },
        },
      }
      local lines = { '<<<', 'c1', '===', 'i1', '>>>', 'normal', '<<<', 'c2', '===', 'i2', '>>>' }
      local result = diff:generate_split_conflict(conflicts, lines)

      assert.are.equal(2, #result.marks)

      -- Line 6 ('normal') is between the two conflicts — untouched on both panels
      assert.are.equal('normal', result.current_lines[6])
      assert.are.equal('normal', result.previous_lines[6])

      -- No lnum_change should reference the non-conflict line
      for _, lc in ipairs(result.lnum_changes) do
        assert.are_not.equal(6, lc.lnum)
      end
    end)
  end)

  describe('generate dispatches conflicts', function()
    it('should dispatch to unified_conflict when conflicts provided', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
      }
      local lines = { '<<<', 'c', '===', 'i', '>>>' }
      local result = diff:generate({}, lines, 'unified', { conflicts = conflicts })

      assert.are.equal(1, #result.marks)
      assert.are.equal('conflict', result.marks[1].type)
    end)

    it('should dispatch to split_conflict when conflicts provided', function()
      local diff = Diff()
      local conflicts = {
        {
          current = { top = 1, bot = 2 },
          ancestor = nil,
          middle = { top = 3, bot = 3 },
          incoming = { top = 4, bot = 5 },
        },
      }
      local lines = { '<<<', 'c', '===', 'i', '>>>' }
      local result = diff:generate({}, lines, 'split', { conflicts = conflicts })

      assert.are.equal(1, #result.marks)
      assert.are.equal('conflict', result.marks[1].type)
    end)
  end)

  describe('unified data invariants', function()
    local invariants = require('tests.helpers.diff_invariants')

    it('should satisfy all invariants for an add hunk', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local result = diff:generate_unified({ hunk }, { 'new1', 'new2' })

      invariants.assert_unified_diff(result)
    end)

    it('should satisfy all invariants for a remove hunk', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local result = diff:generate_unified({ hunk }, { 'a', 'b', 'c', 'd' })

      invariants.assert_unified_diff(result)
    end)

    it('should satisfy all invariants for a change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local result = diff:generate_unified({ hunk }, { 'a', 'new', 'c' })

      invariants.assert_unified_diff(result)
    end)

    it('should satisfy all invariants for multiple mixed hunks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local hunk2 = make_hunk('@@ -4,2 +6,0 @@', { '-removed1', '-removed2' })
      local hunk3 = make_hunk('@@ -7,1 +7,2 @@', { '-old', '+changed1', '+changed2' })
      local diff = Diff()
      local result = diff:generate_unified(
        { hunk1, hunk2, hunk3 },
        { 'new1', 'new2', 'a', 'b', 'c', 'd', 'changed1', 'changed2' }
      )

      invariants.assert_unified_diff(result)
    end)

    it('should satisfy all invariants with no hunks', function()
      local diff = Diff()
      local result = diff:generate_unified({}, { 'a', 'b', 'c' })

      invariants.assert_unified_diff(result)
    end)

    it('should have lnum_changes only within mark ranges', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local result = diff:generate_unified({ hunk }, { 'a', 'new', 'c' })

      for _, lc in ipairs(result.lnum_changes) do
        local within_mark = false
        for _, mark in ipairs(result.marks) do
          if lc.lnum >= mark.top and lc.lnum <= mark.bot then
            within_mark = true
            break
          end
        end
        assert.is_true(within_mark, string.format('lnum_change at %d is outside all marks', lc.lnum))
      end
    end)

    it('should have top_relative and bot_relative on all marks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -2,1 +3,1 @@', { '-old', '+new' })
      local diff = Diff()
      local result = diff:generate_unified({ hunk1, hunk2 }, { 'added', 'a', 'new' })

      for i, mark in ipairs(result.marks) do
        assert.is_not_nil(mark.top_relative, string.format('marks[%d] missing top_relative', i))
        assert.is_not_nil(mark.bot_relative, string.format('marks[%d] missing bot_relative', i))
      end
    end)

    it('should satisfy all invariants for a large multi-line change', function()
      local diff_lines = {}
      for i = 1, 10 do
        diff_lines[#diff_lines + 1] = '-old' .. i
      end
      for i = 1, 15 do
        diff_lines[#diff_lines + 1] = '+new' .. i
      end
      local hunk = make_hunk('@@ -1,10 +1,15 @@', diff_lines)
      local diff = Diff()
      local lines = {}
      for i = 1, 15 do
        lines[i] = 'new' .. i
      end
      local result = diff:generate_unified({ hunk }, lines)

      invariants.assert_unified_diff(result)
    end)

    it('should have correct structure for deleted file', function()
      local hunk = make_hunk('@@ -1,3 +0,0 @@', { '-a', '-b', '-c' })
      local diff = Diff()
      local result = diff:generate_unified_deleted({ hunk }, { 'a', 'b', 'c' })

      assert.is_truthy(result.lines)
      assert.is_truthy(result.marks)
      assert.is_truthy(result.lnum_changes)
      assert.is_truthy(result.stat)
      invariants.assert_stat_consistency(result.stat, result.lnum_changes)
      -- All lnum_changes should be remove
      for _, lc in ipairs(result.lnum_changes) do
        assert.are.equal('remove', lc.type)
      end
      assert.are.equal(3, #result.lnum_changes)
    end)

    it('should have single mark for deleted file', function()
      local hunk = make_hunk('@@ -1,5 +0,0 @@', { '-a', '-b', '-c', '-d', '-e' })
      local diff = Diff()
      local result = diff:generate_unified_deleted({ hunk }, { 'a', 'b', 'c', 'd', 'e' })

      assert.are.equal(1, #result.marks)
      assert.are.equal(1, result.marks[1].top)
      assert.are.equal('remove', result.marks[1].type)
    end)
  end)

  describe('split data invariants', function()
    local invariants = require('tests.helpers.diff_invariants')

    it('should satisfy all invariants for an add hunk', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'new1', 'new2' })

      invariants.assert_split_diff(result)
    end)

    it('should satisfy all invariants for a remove hunk', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'a', 'b', 'c', 'd' })

      invariants.assert_split_diff(result)
    end)

    it('should satisfy all invariants for a change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'a', 'new', 'c' })

      invariants.assert_split_diff(result)
    end)

    it('should satisfy all invariants for multiple mixed hunks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local hunk2 = make_hunk('@@ -4,2 +6,0 @@', { '-removed1', '-removed2' })
      local hunk3 = make_hunk('@@ -7,1 +7,2 @@', { '-old', '+changed1', '+changed2' })
      local diff = Diff()
      local result = diff:generate_split(
        { hunk1, hunk2, hunk3 },
        { 'new1', 'new2', 'a', 'b', 'c', 'd', 'changed1', 'changed2' }
      )

      invariants.assert_split_diff(result)
    end)

    it('should satisfy all invariants with no hunks', function()
      local diff = Diff()
      local result = diff:generate_split({}, { 'a', 'b', 'c' })

      invariants.assert_split_diff(result)
    end)

    it('should satisfy all invariants for unequal change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,3 @@', { '-old', '+new1', '+new2', '+new3' })
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'a', 'new1', 'new2', 'new3', 'c' })

      invariants.assert_split_diff(result)
    end)

    it('should have void on one side paired with content on the other', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'new1', 'new2' })

      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' then
          -- Void lines should be at positions where the other side has content
          if lc.buftype == 'previous' then
            assert.are_not.equal(
              '',
              result.current_lines[lc.lnum],
              string.format('void at previous[%d] but current is also empty', lc.lnum)
            )
          elseif lc.buftype == 'current' then
            assert.are_not.equal(
              '',
              result.previous_lines[lc.lnum],
              string.format('void at current[%d] but previous is also empty', lc.lnum)
            )
          end
        end
      end
    end)

    it('should satisfy all invariants for a large add hunk', function()
      local diff_lines = {}
      local lines = {}
      for i = 1, 50 do
        diff_lines[i] = '+line' .. i
        lines[i] = 'line' .. i
      end
      local hunk = make_hunk('@@ -0,0 +1,50 @@', diff_lines)
      local diff = Diff()
      local result = diff:generate_split({ hunk }, lines)

      invariants.assert_split_diff(result)
    end)

    it('should have correct structure for deleted file', function()
      local hunk = make_hunk('@@ -1,3 +0,0 @@', { '-a', '-b', '-c' })
      local diff = Diff()
      local result = diff:generate_split_deleted({ hunk }, { 'a', 'b', 'c' })

      assert.is_truthy(result.current_lines)
      assert.is_truthy(result.previous_lines)
      assert.is_truthy(result.marks)
      assert.is_truthy(result.lnum_changes)
      assert.is_truthy(result.stat)
      invariants.assert_split_equal_length(result)
      invariants.assert_stat_consistency(result.stat, result.lnum_changes)
      invariants.assert_split_buftype_present(result.lnum_changes)
      -- Current lines should all be empty
      for _, line in ipairs(result.current_lines) do
        assert.are.equal('', line)
      end
    end)

    it('should satisfy all invariants for a large remove hunk', function()
      local diff_lines = {}
      for i = 1, 30 do
        diff_lines[i] = '-removed' .. i
      end
      local hunk = make_hunk('@@ -3,30 +3,0 @@', diff_lines)
      local diff = Diff()
      local result = diff:generate_split({ hunk }, { 'a', 'b', 'c' })

      invariants.assert_split_diff(result)
    end)
  end)

  -- ============================================================================
  -- ADVERSARIAL EDGE CASES
  -- Designed to probe boundary conditions and stress internal bookkeeping.
  -- ============================================================================
  describe('adversarial unified edge cases', function()
    local invariants = require('tests.helpers.diff_invariants')

    it('back-to-back changes with no gap should produce ascending marks', function()
      -- Two change hunks touching: hunk1 at line 1, hunk2 at line 2.
      -- Tests src_pos tracking when there are zero lines between hunks.
      local h1 = make_hunk('@@ -1,1 +1,1 @@', { '-a', '+A' })
      local h2 = make_hunk('@@ -2,1 +2,1 @@', { '-b', '+B' })
      local result = Diff():generate_unified({ h1, h2 }, { 'A', 'B' })

      invariants.assert_unified_diff(result)
      eq(2, #result.marks)
      -- Marks must be ascending — second mark starts after first ends
      assert.is_true(result.marks[2].top > result.marks[1].bot)
    end)

    it('change with many more removes than adds should have correct mark span', function()
      -- 5 lines removed, 1 line added. The removed lines inflate new_lines.
      -- mark.bot = top + diff_len - 1 = 1 + 6 - 1 = 6
      local h = make_hunk('@@ -1,1 +1,1 @@', { '-a', '-b', '-c', '-d', '-e', '+f' })
      local result = Diff():generate_unified({ h }, { 'f' })

      invariants.assert_unified_diff(result)
      eq(1, #result.marks)
      -- Mark should cover all 6 output lines (5 removes + 1 add)
      eq(6, result.marks[1].bot - result.marks[1].top + 1)
      eq(5, result.stat.removed)
      eq(1, result.stat.added)
    end)

    it('change followed immediately by remove should track new_lines_added correctly', function()
      -- change at 1 inserts extra remove lines, shifting subsequent positions
      local h1 = make_hunk('@@ -1,1 +1,1 @@', { '-old', '+new' })
      local h2 = make_hunk('@@ -3,1 +2,0 @@', { '-removed' })
      local result = Diff():generate_unified({ h1, h2 }, { 'new', 'b' })

      invariants.assert_unified_diff(result)
      eq(2, #result.marks)
      -- All marks within [1, #lines]
      invariants.assert_marks_within_bounds(result.marks, #result.lines)
    end)

    it('remove at the very end of file should produce marks within bounds', function()
      -- Remove after the last current line. The mark starts at top+1.
      local h = make_hunk('@@ -4,2 +3,0 @@', { '-x', '-y' })
      local result = Diff():generate_unified({ h }, { 'a', 'b', 'c' })

      invariants.assert_unified_diff(result)
      -- Lines should be: a, b, c, x, y
      eq(5, #result.lines)
      eq('a', result.lines[1])
      eq('x', result.lines[4])
    end)

    it('add at line 1 followed by change at line 3 should keep marks ascending', function()
      -- Add pushes all subsequent positions forward via new_lines_added=0 for add
      -- (add doesn't increment new_lines_added, change does for its removes)
      local h1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local h2 = make_hunk('@@ -1,1 +3,1 @@', { '-old', '+changed' })
      local result = Diff():generate_unified({ h1, h2 }, { 'new1', 'new2', 'changed', 'd' })

      invariants.assert_unified_diff(result)
      assert.is_true(#result.marks >= 2)
    end)

    it('many adjacent add hunks should all produce separate ascending marks', function()
      -- 5 single-line adds in sequence
      local hunks = {}
      local lines = {}
      for i = 1, 5 do
        hunks[i] = make_hunk(string.format('@@ -0,0 +%d,1 @@', i), { '+line' .. i })
        lines[i] = 'line' .. i
      end
      local result = Diff():generate_unified(hunks, lines)

      invariants.assert_unified_diff(result)
      eq(5, #result.marks)
      eq(5, result.stat.added)
    end)

    it('single-line file with a change should not produce empty output', function()
      local h = make_hunk('@@ -1,1 +1,1 @@', { '-old', '+new' })
      local result = Diff():generate_unified({ h }, { 'new' })

      invariants.assert_unified_diff(result)
      assert.is_true(#result.lines >= 2) -- at least the removed and added line
      eq(1, result.stat.added)
      eq(1, result.stat.removed)
    end)

    it('change 1 line to 20 lines should not lose any lnum_changes', function()
      local diff_lines = { '-original' }
      for i = 1, 20 do
        diff_lines[#diff_lines + 1] = '+line' .. i
      end
      local current_lines = {}
      for i = 1, 20 do
        current_lines[i] = 'line' .. i
      end
      local h = make_hunk('@@ -1,1 +1,20 @@', diff_lines)
      local result = Diff():generate_unified({ h }, current_lines)

      invariants.assert_unified_diff(result)
      eq(1, result.stat.removed)
      eq(20, result.stat.added)
      -- All 21 lnum_changes should be within bounds
      invariants.assert_lnum_changes_within_bounds(result.lnum_changes, #result.lines)
    end)

    it('remove of 20 lines then add of 1 line should have correct stat', function()
      local diff_lines = {}
      for i = 1, 20 do
        diff_lines[i] = '-old' .. i
      end
      diff_lines[21] = '+survivor'
      local h = make_hunk('@@ -1,1 +1,1 @@', diff_lines)
      local result = Diff():generate_unified({ h }, { 'survivor' })

      invariants.assert_unified_diff(result)
      eq(20, result.stat.removed)
      eq(1, result.stat.added)
      eq(21, #result.lines) -- 20 removed + 1 added
    end)

    it('three-hunk cascade: add, change, remove should produce valid output', function()
      -- add at start, change in middle, remove at end
      local h1 = make_hunk('@@ -0,0 +1,1 @@', { '+header' })
      local h2 = make_hunk('@@ -2,1 +3,1 @@', { '-old_mid', '+new_mid' })
      local h3 = make_hunk('@@ -4,1 +4,0 @@', { '-tail' })
      local result = Diff():generate_unified({ h1, h2, h3 }, { 'header', 'a', 'new_mid', 'b' })

      invariants.assert_unified_diff(result)
      eq(3, #result.marks)
    end)
  end)

  describe('adversarial split edge cases', function()
    local invariants = require('tests.helpers.diff_invariants')

    it('back-to-back changes should produce ascending non-overlapping marks', function()
      local h1 = make_hunk('@@ -1,1 +1,1 @@', { '-a', '+A' })
      local h2 = make_hunk('@@ -2,1 +2,1 @@', { '-b', '+B' })
      local result = Diff():generate_split({ h1, h2 }, { 'A', 'B' })

      invariants.assert_split_diff(result)
      eq(2, #result.marks)
      assert.is_true(result.marks[2].top > result.marks[1].bot)
    end)

    it('change with 5 removes and 1 add should pad voids correctly', function()
      local h = make_hunk('@@ -1,1 +1,1 @@', { '-a', '-b', '-c', '-d', '-e', '+f' })
      local result = Diff():generate_split({ h }, { 'f' })

      invariants.assert_split_diff(result)
      -- Previous should have 5 real lines, current should have 1 real + 4 void
      local void_count = 0
      for _, line in ipairs(result.current_lines) do
        if line == '' then void_count = void_count + 1 end
      end
      assert.is_true(void_count >= 4)

      -- Both sides equal length
      eq(#result.current_lines, #result.previous_lines)
    end)

    it('change with 1 remove and 10 adds should pad previous with voids', function()
      local diff_lines = { '-old' }
      local current = {}
      for i = 1, 10 do
        diff_lines[#diff_lines + 1] = '+new' .. i
        current[i] = 'new' .. i
      end
      local h = make_hunk('@@ -1,1 +1,10 @@', diff_lines)
      local result = Diff():generate_split({ h }, current)

      invariants.assert_split_diff(result)
      -- Previous should have 1 real + 9 voids
      local prev_void_count = 0
      for _, line in ipairs(result.previous_lines) do
        if line == '' then prev_void_count = prev_void_count + 1 end
      end
      assert.is_true(prev_void_count >= 9)
    end)

    it('remove at end of file should not exceed line bounds', function()
      local h = make_hunk('@@ -4,2 +3,0 @@', { '-x', '-y' })
      local result = Diff():generate_split({ h }, { 'a', 'b', 'c' })

      invariants.assert_split_diff(result)
      -- Current should have voids where removed lines were
      eq(5, #result.current_lines) -- 3 original + 2 removed slots
    end)

    it('add then remove should keep both sides equal length', function()
      local h1 = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local h2 = make_hunk('@@ -2,1 +4,0 @@', { '-removed' })
      local result = Diff():generate_split({ h1, h2 }, { 'new1', 'new2', 'a', 'b' })

      invariants.assert_split_diff(result)
      eq(#result.current_lines, #result.previous_lines)
    end)

    it('change of entire single-line file should produce non-empty output', function()
      local h = make_hunk('@@ -1,1 +1,1 @@', { '-old', '+new' })
      local result = Diff():generate_split({ h }, { 'new' })

      invariants.assert_split_diff(result)
      eq(1, #result.current_lines)
      eq(1, #result.previous_lines)
      eq('new', result.current_lines[1])
      eq('old', result.previous_lines[1])
    end)

    it('mixed add/change/remove across file should maintain equal length', function()
      -- add at 1, change at 3, remove at 5
      local h1 = make_hunk('@@ -0,0 +1,1 @@', { '+inserted' })
      local h2 = make_hunk('@@ -2,1 +3,1 @@', { '-was', '+now' })
      local h3 = make_hunk('@@ -4,1 +4,0 @@', { '-gone' })
      local result = Diff():generate_split({ h1, h2, h3 }, { 'inserted', 'a', 'now', 'b' })

      invariants.assert_split_diff(result)
      eq(#result.current_lines, #result.previous_lines)
      eq(3, #result.marks)
    end)

    it('20 removed lines then 1 add should produce large void block on current', function()
      local diff_lines = {}
      for i = 1, 20 do
        diff_lines[i] = '-old' .. i
      end
      diff_lines[21] = '+survivor'
      local h = make_hunk('@@ -1,1 +1,1 @@', diff_lines)
      local result = Diff():generate_split({ h }, { 'survivor' })

      invariants.assert_split_diff(result)
      eq(20, #result.previous_lines) -- 20 real removed lines
      eq(20, #result.current_lines) -- 1 real + 19 voids

      -- Verify void count
      local current_voids = 0
      for _, line in ipairs(result.current_lines) do
        if line == '' then current_voids = current_voids + 1 end
      end
      eq(19, current_voids)
    end)
  end)

  describe('adversarial PatchPreviewComponent pipeline', function()
    local invariants = require('tests.helpers.diff_invariants')
    local PatchPreviewComponent = require('vgit.ui.components.PatchPreviewComponent')

    it('diff_file with no marks should produce no output marks', function()
      local component = PatchPreviewComponent({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'empty.lua',
          filetype = 'lua',
          original_lines = { 'same' },
          current_lines = { 'same' },
          diff = {
            lines = { 'same' },
            lnum_changes = {},
            marks = {},
            stat = { added = 0, removed = 0 },
          },
        },
      }

      local lines, _, _, marks = component:build_patch_lines_from_entries(entries)

      -- Should still produce file header lines but no change marks
      assert.is_true(#lines > 0)
      eq(0, #marks)
    end)

    it('two diff_files where second has empty diff should not corrupt marks', function()
      local h = make_hunk('@@ -1,1 +1,1 @@', { '-old', '+new' })
      local real_diff = Diff():generate_unified({ h }, { 'new' })

      local component = PatchPreviewComponent({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'changed.lua',
          filetype = 'lua',
          original_lines = { 'old' },
          current_lines = { 'new' },
          diff = real_diff,
        },
        {
          type = 'diff_file',
          filename = 'unchanged.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = {},
          diff = {
            lines = {},
            lnum_changes = {},
            marks = {},
            stat = { added = 0, removed = 0 },
          },
        },
      }

      local lines, _, _, marks = component:build_patch_lines_from_entries(entries)

      -- Only first file should contribute marks
      assert.is_true(#lines > 0)
      if #marks > 0 then invariants.assert_patch_marks(marks, #lines) end
    end)

    it('diff_file with 20 hunks should produce 20 ascending marks', function()
      local hunks = {}
      local current = {}
      for i = 1, 40 do
        current[i] = 'line' .. i
      end
      -- Create 20 change hunks at even positions
      for i = 1, 20 do
        local pos = i * 2
        hunks[i] = make_hunk(string.format('@@ -%d,1 +%d,1 @@', pos, pos), { '-old' .. i, '+line' .. pos })
      end
      local real_diff = Diff():generate_unified(hunks, current)

      local component = PatchPreviewComponent({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'many_hunks.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = current,
          diff = real_diff,
        },
      }

      local lines, _, _, marks = component:build_patch_lines_from_entries(entries)

      assert.is_true(#marks > 0)
      invariants.assert_patch_marks(marks, #lines)
    end)

    it('three diff_files should produce marks that are globally ascending', function()
      local h1 = make_hunk('@@ -1,1 +1,1 @@', { '-a', '+b' })
      local h2 = make_hunk('@@ -1,1 +1,1 @@', { '-c', '+d' })
      local h3 = make_hunk('@@ -1,1 +1,1 @@', { '-e', '+f' })

      local d1 = Diff():generate_unified({ h1 }, { 'b' })
      local d2 = Diff():generate_unified({ h2 }, { 'd' })
      local d3 = Diff():generate_unified({ h3 }, { 'f' })

      local component = PatchPreviewComponent({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'a.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = { 'b' },
          diff = d1,
        },
        {
          type = 'diff_file',
          filename = 'b.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = { 'd' },
          diff = d2,
        },
        {
          type = 'diff_file',
          filename = 'c.lua',
          filetype = 'lua',
          original_lines = {},
          current_lines = { 'f' },
          diff = d3,
        },
      }

      local lines, _, _, marks = component:build_patch_lines_from_entries(entries)

      eq(3, #marks)
      invariants.assert_patch_marks(marks, #lines)
    end)

    it('diff_file entry with very large change should have line_numbers matching lines', function()
      local diff_lines = { '-original' }
      local current = {}
      for i = 1, 50 do
        diff_lines[#diff_lines + 1] = '+new' .. i
        current[i] = 'new' .. i
      end
      local h = make_hunk('@@ -1,1 +1,50 @@', diff_lines)
      local real_diff = Diff():generate_unified({ h }, current)

      local component = PatchPreviewComponent({})
      local entries = {
        {
          type = 'diff_file',
          filename = 'huge.lua',
          filetype = 'lua',
          original_lines = { 'original' },
          current_lines = current,
          diff = real_diff,
        },
      }

      local lines, _, _, patch_marks, line_numbers = component:build_patch_lines_from_entries(entries)

      eq(#lines, #line_numbers)
      if #patch_marks > 0 then invariants.assert_patch_marks(patch_marks, #lines) end
    end)
  end)
end)
