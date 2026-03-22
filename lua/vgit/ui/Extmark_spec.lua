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
    it('should return col + 1', function()
      local extmark = Extmark(0)
      assert.are.equal(6, extmark:derive_id(5))
      assert.are.equal(1, extmark:derive_id(0))
      assert.are.equal(11, extmark:derive_id(10))
    end)

    it('should produce different IDs for different cols', function()
      local extmark = Extmark(0)
      local id1 = extmark:derive_id(0)
      local id2 = extmark:derive_id(1)
      assert.are_not.equal(id1, id2)
    end)

    it('should always return a positive ID', function()
      local extmark = Extmark(0)
      assert.is_true(extmark:derive_id(0) > 0)
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
