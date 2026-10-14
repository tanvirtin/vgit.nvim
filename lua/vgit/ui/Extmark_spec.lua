local Extmark = require('vgit.ui.Extmark')

local eq = assert.are.same

describe('Extmark:', function()
  describe('constructor', function()
    it('should create with buffer number and namespace', function()
      local extmark = Extmark(0)
      assert.are.equal(0, extmark.bufnr)
      assert.is_number(extmark.ns_id)
    end)

    it('should create namespace with extension', function()
      local extmark = Extmark(0, 'signs')
      assert.is_number(extmark.ns_id)
    end)
  end)

  describe('derive_id', function()
    it('should offset each extmark kind into its own id space', function()
      local extmark = Extmark(0)
      assert.are.equal(15, extmark:derive_id(5, 'text'))
      assert.are.equal(10, extmark:derive_id(0, 'text'))
      assert.are.equal(105, extmark:derive_id(5, 'sign'))
      assert.are.equal(1005, extmark:derive_id(5, 'lnum'))
      assert.are.equal(10005, extmark:derive_id(5, 'virt_line'))
    end)

    it('should not collide across kinds on the same row', function()
      local extmark = Extmark(0)
      local row = 7
      local ids = {
        extmark:derive_id(row, 'text'),
        extmark:derive_id(row, 'sign'),
        extmark:derive_id(row, 'lnum'),
        extmark:derive_id(row, 'virt_line'),
      }

      local seen = {}
      for _, id in ipairs(ids) do
        assert.is_nil(seen[id])
        seen[id] = true
      end
    end)

    it('should error on an unknown kind', function()
      local extmark = Extmark(0)
      assert.has_error(function()
        extmark:derive_id(0, 'bogus')
      end)
    end)

    it('should produce different IDs for different rows', function()
      local extmark = Extmark(0)
      local id1 = extmark:derive_id(0, 'text')
      local id2 = extmark:derive_id(1, 'text')
      assert.are_not.equal(id1, id2)
    end)

    it('should always return a positive ID', function()
      local extmark = Extmark(0)
      assert.is_true(extmark:derive_id(0, 'text') > 0)
    end)
  end)

  describe('kind isolation', function()
    it('should keep a sign and a text on the same row', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c', 'd' })
      local extmark = Extmark(buf)

      extmark:sign({ row = 3, name = 'GitConflictCurrentMark' })
      extmark:text({ text = '(Current Change)', hl = 'GitComment', row = 3, col = 0, pos = 'eol' })

      local marks = vim.api.nvim_buf_get_extmarks(buf, extmark.ns_id, 0, -1, { details = true })
      assert.are.equal(2, #marks)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should keep a text and a virtual line on the same row', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c', 'd' })
      local extmark = Extmark(buf)

      extmark:text({ text = 'inline', hl = 'GitComment', row = 2, col = 0 })
      extmark:virt_line({ text = 'help', hl = 'GitComment', row = 2, above = true })

      local marks = vim.api.nvim_buf_get_extmarks(buf, extmark.ns_id, 0, -1, { details = true })
      assert.are.equal(2, #marks)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('highlight', function()
    it('should find pattern matches in a single line', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world hello' })
      local extmark = Extmark(buf)

      local ok, result = extmark:highlight({
        hl = 'Search',
        row = 0,
        pattern = 'hello',
      })

      assert.is_true(ok)
      assert.are.equal(2, #result) -- two matches of 'hello'

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should return empty result when no matches', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world' })
      local extmark = Extmark(buf)

      local ok, result = extmark:highlight({
        hl = 'Search',
        row = 0,
        pattern = 'xyz',
      })

      assert.is_true(ok)
      assert.are.equal(0, #result)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should search all lines when row is nil', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'foo bar', 'baz foo', 'nothing' })
      local extmark = Extmark(buf)

      local ok, result = extmark:highlight({
        hl = 'Search',
        pattern = 'foo',
      })

      assert.is_true(ok)
      assert.are.equal(2, #result) -- one match per line for lines 1 and 2

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should return empty on empty buffer with row', function()
      local buf = vim.api.nvim_create_buf(false, true)
      local extmark = Extmark(buf)

      local ok, result = extmark:highlight({
        hl = 'Search',
        row = 0,
        pattern = 'test',
      })

      assert.is_true(ok)
      assert.are.equal(0, #result)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should handle col_range highlighting', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world' })
      local extmark = Extmark(buf)

      local ok = extmark:highlight({
        hl = 'Search',
        row = 0,
        col_range = { from = 0, to = 5 },
      })

      assert.is_true(ok)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should handle line_hl highlighting', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello world' })
      local extmark = Extmark(buf)

      local ok = extmark:highlight({
        hl = 'CursorLine',
        row = 0,
        line_hl = true,
      })

      assert.is_true(ok)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)

  describe('clear', function()
    it('should clear extmarks without error', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'hello' })
      local extmark = Extmark(buf)

      local ok = extmark:clear()
      assert.is_true(ok)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)

    it('should clear with range', function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'a', 'b', 'c' })
      local extmark = Extmark(buf)

      local ok = extmark:clear(0, 1)
      assert.is_true(ok)

      vim.api.nvim_buf_delete(buf, { force = true })
    end)
  end)
end)
