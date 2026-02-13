local eq = assert.are.same

local GitHunk = require('vgit.git.GitHunk')
local LiveHunkGenerator = require('vgit.core.diff.hunks.LiveHunkGenerator')

describe('LiveHunkGenerator:', function()
  local gen

  before_each(function()
    gen = LiveHunkGenerator()
  end)

  describe('_determine_type', function()
    it('should return add when count_o is 0 and count_c > 0', function()
      eq('add', gen:_determine_type(0, 5))
    end)

    it('should return add when count_o is 0 and count_c is 1', function()
      eq('add', gen:_determine_type(0, 1))
    end)

    it('should return remove when count_o > 0 and count_c is 0', function()
      eq('remove', gen:_determine_type(3, 0))
    end)

    it('should return remove when count_o is 1 and count_c is 0', function()
      eq('remove', gen:_determine_type(1, 0))
    end)

    it('should return change when both counts are > 0', function()
      eq('change', gen:_determine_type(2, 3))
    end)

    it('should return change when both counts are equal', function()
      eq('change', gen:_determine_type(5, 5))
    end)

    it('should return change when both counts are 0', function()
      eq('change', gen:_determine_type(0, 0))
    end)
  end)

  describe('_create_hunk', function()
    it('should create an add hunk with correct fields', function()
      local orig = { 'a', 'b', 'c' }
      local curr = { 'a', 'x', 'y', 'b', 'c' }

      local hunk = gen:_create_hunk(1, 0, 2, 2, orig, curr)

      eq('add', hunk.type)
      eq(2, hunk.top)
      eq(3, hunk.bot) -- start_c + max(count_c - 1, 0) = 2 + 1
    end)

    it('should create a remove hunk with correct fields', function()
      local orig = { 'a', 'b', 'c', 'd' }
      local curr = { 'a', 'd' }

      local hunk = gen:_create_hunk(2, 2, 2, 0, orig, curr)

      eq('remove', hunk.type)
      eq(2, hunk.top)
      eq(2, hunk.bot) -- start_c + max(0-1, 0) = 2 + 0
    end)

    it('should create a change hunk with correct fields', function()
      local orig = { 'a', 'b', 'c' }
      local curr = { 'a', 'x', 'c' }

      local hunk = gen:_create_hunk(2, 1, 2, 1, orig, curr)

      eq('change', hunk.type)
      eq(2, hunk.top)
      eq(2, hunk.bot)
    end)

    it('should push removed lines with - prefix', function()
      local orig = { 'a', 'old1', 'old2' }
      local curr = { 'a' }

      local hunk = gen:_create_hunk(2, 2, 2, 0, orig, curr)

      eq(2, hunk.stat.removed)
      eq(0, hunk.stat.added)
      assert.is_true(vim.tbl_contains(hunk.diff, '-old1'))
      assert.is_true(vim.tbl_contains(hunk.diff, '-old2'))
    end)

    it('should push added lines with + prefix', function()
      local orig = { 'a' }
      local curr = { 'a', 'new1', 'new2' }

      local hunk = gen:_create_hunk(1, 0, 2, 2, orig, curr)

      eq(0, hunk.stat.removed)
      eq(2, hunk.stat.added)
      assert.is_true(vim.tbl_contains(hunk.diff, '+new1'))
      assert.is_true(vim.tbl_contains(hunk.diff, '+new2'))
    end)

    it('should push both removed and added lines for change', function()
      local orig = { 'a', 'old', 'c' }
      local curr = { 'a', 'new', 'c' }

      local hunk = gen:_create_hunk(2, 1, 2, 1, orig, curr)

      eq(1, hunk.stat.removed)
      eq(1, hunk.stat.added)
      assert.is_true(vim.tbl_contains(hunk.diff, '-old'))
      assert.is_true(vim.tbl_contains(hunk.diff, '+new'))
    end)

    it('should generate correct header', function()
      local hunk = gen:_create_hunk(5, 3, 5, 2, { 'a', 'b', 'c', 'd', 'e', 'f', 'g' }, { 'a', 'b', 'c', 'd', 'x', 'y' })

      eq('@@ -5,3 +5,2 @@', hunk.header)
    end)

    it('should skip nil lines in original', function()
      local orig = { 'a' }
      local curr = { 'a', 'b' }

      -- start_o = 5, but orig only has 1 element, so orig[5] is nil
      local hunk = gen:_create_hunk(5, 2, 1, 0, orig, curr)

      -- Should not error, just skip the nil entries
      eq('remove', hunk.type)
    end)
  end)

  describe('generate', function()
    it('should error when original_lines is nil', function()
      assert.has_error(function()
        gen:generate(nil, { 'line1' })
      end)
    end)

    it('should error when current_lines is nil', function()
      assert.has_error(function()
        gen:generate({ 'line1' }, nil)
      end)
    end)

    it('should return empty hunks for identical content', function()
      local lines = { 'line1', 'line2', 'line3' }
      local hunks = gen:generate(lines, lines)

      eq({}, hunks)
    end)

    it('should detect additions', function()
      local orig = { 'a', 'c' }
      local curr = { 'a', 'b', 'c' }

      local hunks = gen:generate(orig, curr)

      assert.is_true(#hunks > 0)

      local total_added = 0
      for _, h in ipairs(hunks) do
        total_added = total_added + h.stat.added
      end
      assert.is_true(total_added > 0)
    end)

    it('should detect removals', function()
      local orig = { 'a', 'b', 'c' }
      local curr = { 'a', 'c' }

      local hunks = gen:generate(orig, curr)

      assert.is_true(#hunks > 0)

      local total_removed = 0
      for _, h in ipairs(hunks) do
        total_removed = total_removed + h.stat.removed
      end
      assert.is_true(total_removed > 0)
    end)

    it('should detect changes', function()
      local orig = { 'a', 'b', 'c' }
      local curr = { 'a', 'x', 'c' }

      local hunks = gen:generate(orig, curr)

      assert.is_true(#hunks > 0)
    end)

    it('should return hunks with valid GitHunk structure', function()
      local orig = { 'hello' }
      local curr = { 'world' }

      local hunks = gen:generate(orig, curr)

      assert.is_true(#hunks > 0)
      local hunk = hunks[1]
      assert.is_not_nil(hunk.header)
      assert.is_not_nil(hunk.top)
      assert.is_not_nil(hunk.bot)
      assert.is_not_nil(hunk.type)
      assert.is_not_nil(hunk.stat)
      assert.is_not_nil(hunk.diff)
    end)

    it('should handle empty original (all added)', function()
      local hunks = gen:generate({}, { 'a', 'b' })

      local total_added = 0
      for _, h in ipairs(hunks) do
        total_added = total_added + h.stat.added
      end
      assert.is_true(total_added > 0)
    end)

    it('should handle empty current (all removed)', function()
      local hunks = gen:generate({ 'a', 'b' }, {})

      local total_removed = 0
      for _, h in ipairs(hunks) do
        total_removed = total_removed + h.stat.removed
      end
      assert.is_true(total_removed > 0)
    end)

    it('should handle both empty', function()
      local hunks = gen:generate({}, {})

      eq({}, hunks)
    end)

    it('should accept algorithm option', function()
      local orig = { 'a', 'b', 'c' }
      local curr = { 'a', 'x', 'c' }

      -- Should not error with different algorithm
      local hunks = gen:generate(orig, curr, { algorithm = 'patience' })

      assert.is_true(#hunks > 0)
    end)
  end)
end)
