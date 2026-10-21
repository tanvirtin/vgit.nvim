local api = require('vgit.api')

local eq = assert.are.same

local function kinds(patch)
  return vim.tbl_map(function(row)
    return row.kind
  end, patch.rows)
end

local function lines_of(n, changed)
  local lines = {}

  for i = 1, n do
    lines[i] = changed and changed[i] or ('line ' .. i)
  end

  return lines
end

describe('vgit.api:', function()
  describe('diff', function()
    it('should diff two line arrays without a repository', function()
      local diff = api.diff({ 'a', 'b', 'c' }, { 'a', 'B', 'c' })

      eq({ 'a', 'b', 'B', 'c' }, diff.lines)
      eq({ added = 1, removed = 1 }, diff.stat)
    end)

    it('should diff a new file and a deleted file', function()
      eq({ added = 2, removed = 0 }, api.diff({}, { 'a', 'b' }).stat)
      eq(2, #api.diff({ 'a', 'b' }, {}).lines)
    end)
  end)

  describe('patch', function()
    it('should lay out the change with context and real line numbers on both sides', function()
      local patch = api.patch({
        {
          filename = 'a.txt',
          old_lines = lines_of(20),
          new_lines = lines_of(20, { [10] = 'changed' }),
        },
      }, { header = false })

      eq({ 'context', 'context', 'context', 'remove', 'add', 'context', 'context', 'context' }, kinds(patch))
      eq({ 'line 7', 'line 8', 'line 9', 'line 10', 'changed', 'line 11', 'line 12', 'line 13' }, patch.lines)
      eq({ 10, nil }, { patch.rows[4].old_lnum, patch.rows[4].new_lnum })
      eq({ nil, 10 }, { patch.rows[5].old_lnum, patch.rows[5].new_lnum })
      eq({ 11, 11 }, { patch.rows[6].old_lnum, patch.rows[6].new_lnum })
      eq({ added = 1, removed = 1 }, patch.stat)
    end)

    it('should separate distant hunks with a hunk row and honour the context option', function()
      local patch = api.patch({
        {
          filename = 'a.txt',
          old_lines = lines_of(30),
          new_lines = lines_of(30, { [5] = 'x', [25] = 'y' }),
        },
      }, { header = false, context = 1 })

      eq({ 'context', 'remove', 'add', 'context', 'hunk', 'context', 'remove', 'add', 'context' }, kinds(patch))
    end)

    it('should head each file with its name unless asked not to', function()
      local patch = api.patch({ { filename = 'a.txt', old_lines = { 'a' }, new_lines = { 'b' } } })

      eq({ 'file', 'file', 'file' }, vim.list_slice(kinds(patch), 1, 3))
      eq('a.txt', patch.lines[2])
    end)

    it('should give line backgrounds and changed words as highlights relative to the patch', function()
      local patch = api.patch({
        { filename = 'a.txt', old_lines = { 'local x = 1' }, new_lines = { 'local x = 2' } },
      }, { header = false, syntax = false })

      local function has(row, group, from, to)
        for _, hl in ipairs(patch.highlights) do
          if hl.row == row and hl.hl_group == group and (not from or (hl.col_start == from and hl.col_end == to)) then
            return true
          end
        end

        return false
      end

      assert.is_true(has(0, 'GitSignsDeleteLn'))
      assert.is_true(has(1, 'GitSignsAddLn'))
      assert.is_true(has(0, 'GitWordDelete', 10, 11))
      assert.is_true(has(1, 'GitWordAdd', 10, 11))
    end)

    it('should map syntax captures from each side onto the patch rows', function()
      local patch = api.patch({
        { filename = 'a.lua', old_lines = { 'local x = 1' }, new_lines = { 'local y = 1' } },
      }, { header = false })

      local rows = {}

      for _, hl in ipairs(patch.highlights) do
        if hl.syntax then rows[hl.row] = true end
      end

      eq({ [0] = true, [1] = true }, rows)
    end)
  end)

  describe('patch_text', function()
    it('should give a classic unified diff for plain-text readers', function()
      eq(
        { '--- a.txt', '+++ a.txt', '@@ -1,2 +1,2 @@', '-a', '+A', ' b' },
        api.patch_text({ { filename = 'a.txt', old_lines = { 'a', 'b' }, new_lines = { 'A', 'b' } } })
      )
      eq({}, api.patch_text({ { filename = 'a.txt', old_lines = { 'a' }, new_lines = { 'a' } } }))
    end)
  end)
end)
