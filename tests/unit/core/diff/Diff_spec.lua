local Diff = require('vgit.core.diff.Diff')
local GitHunk = require('vgit.git.GitHunk')

-- Helper to create a hunk with diff lines
local function make_hunk(header, diff_lines)
  local hunk = GitHunk(header)
  for _, line in ipairs(diff_lines or {}) do
    hunk:push(line)
  end
  return hunk
end

describe('Diff', function()
  describe('constructor', function()
    it('should set defaults', function()
      local diff = Diff()
      assert.are.same({}, diff.hunks)
      assert.are.same({}, diff.marks)
      assert.are.same({}, diff.lines)
      assert.are.same({}, diff.lnum_changes)
      assert.are.same({ added = 0, removed = 0 }, diff.stat)
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
      assert.are.same(lines, result.lines)
    end)

    it('should dispatch to split', function()
      local diff = Diff()
      local lines = { 'line1', 'line2' }
      local result = diff:generate({}, lines, 'split')
      assert.are.same(lines, result.current_lines)
      assert.are.same(lines, result.previous_lines)
    end)

    it('should dispatch to unified_deleted when is_deleted', function()
      local diff = Diff()
      local lines = { 'old1', 'old2' }
      local result = diff:generate({}, lines, 'unified', { is_deleted = true })
      assert.are.same(lines, result.lines)
    end)

    it('should dispatch to split_deleted when is_deleted', function()
      local diff = Diff()
      local lines = { 'old1', 'old2' }
      local result = diff:generate({}, lines, 'split', { is_deleted = true })
      assert.are.same(lines, result.previous_lines)
    end)
  end)

  describe('generate_unified', function()
    it('should return lines unchanged when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b', 'c' }
      local result = diff:generate_unified({}, lines)
      assert.are.same(lines, result.lines)
      assert.are.same({}, result.hunks)
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
  end)

  describe('generate_split', function()
    it('should return lines in both sides when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_split({}, lines)
      assert.are.same(lines, result.current_lines)
      assert.are.same(lines, result.previous_lines)
    end)

    it('should handle add hunk with void in previous', function()
      local hunk = make_hunk('@@ -0,0 +1,2 @@', { '+new1', '+new2' })
      local diff = Diff()
      local lines = { 'new1', 'new2' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal('add', result.marks[1].type)

      -- Previous lines should have void (empty string) where adds are
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' and lc.buftype == 'previous' then
          void_count = void_count + 1
        end
      end
      assert.are.equal(2, void_count)
    end)

    it('should handle remove hunk with void in current', function()
      local hunk = make_hunk('@@ -3,2 +3,0 @@', { '-removed1', '-removed2' })
      local diff = Diff()
      local lines = { 'a', 'b', 'c', 'd' }
      local result = diff:generate_split({ hunk }, lines)

      assert.are.equal(1, #result.marks)
      assert.are.equal('remove', result.marks[1].type)

      -- Current lines should have void where removes are
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' and lc.buftype == 'current' then
          void_count = void_count + 1
        end
      end
      assert.are.equal(2, void_count)
    end)

    it('should handle change hunk', function()
      local hunk = make_hunk('@@ -2,1 +2,1 @@', { '-old', '+new' })
      local diff = Diff()
      local lines = { 'a', 'new', 'c' }
      local result = diff:generate_split({ hunk }, lines)

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

    it('should accumulate stats from multiple hunks', function()
      local hunk1 = make_hunk('@@ -0,0 +1,1 @@', { '+added' })
      local hunk2 = make_hunk('@@ -0,0 +3,1 @@', { '+another' })
      local diff = Diff()
      local lines = { 'added', 'middle', 'another' }
      local result = diff:generate_split({ hunk1, hunk2 }, lines)

      assert.are.equal(2, result.stat.added)
      assert.are.equal(2, #result.marks)
    end)
  end)

  describe('generate_unified_deleted', function()
    it('should return lines unchanged when no hunks', function()
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_unified_deleted({}, lines)
      assert.are.same(lines, result.lines)
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
      assert.are.same(lines, result.previous_lines)
      assert.are.same({}, result.current_lines)
    end)

    it('should mark previous as remove and current as void', function()
      local hunk = make_hunk('@@ -1,2 +0,0 @@', { '-a', '-b' })
      local diff = Diff()
      local lines = { 'a', 'b' }
      local result = diff:generate_split_deleted({ hunk }, lines)

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

      local types = {}
      for _, lc in ipairs(result.lnum_changes) do
        types[lc.type] = (types[lc.type] or 0) + 1
      end
      assert.is_not_nil(types.conflict_ancestor_mark)
      assert.is_not_nil(types.conflict_ancestor)
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

      assert.are.equal(1, #result.marks)
      assert.is_not_nil(result.previous_lines)
      assert.is_not_nil(result.current_lines)

      -- Should have void entries in the split view
      local void_count = 0
      for _, lc in ipairs(result.lnum_changes) do
        if lc.type == 'void' then void_count = void_count + 1 end
      end
      assert.is_true(void_count > 0)
    end)
  end)
end)
