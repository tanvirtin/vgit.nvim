local Extmark = require('vgit.ui.Extmark')

describe('Extmark', function()
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

    it('should set default groups', function()
      local extmark = Extmark(0)
      assert.are.equal(10, extmark.groups.text)
      assert.are.equal(100, extmark.groups.sign)
      assert.are.equal(1000, extmark.groups.lnum)
    end)
  end)

  describe('derive_id', function()
    it('should produce deterministic IDs for text group', function()
      local extmark = Extmark(0)
      local id = extmark:derive_id(5, 'text')
      assert.are.equal(15, id) -- base 10 + col 5
    end)

    it('should produce deterministic IDs for sign group', function()
      local extmark = Extmark(0)
      local id = extmark:derive_id(3, 'sign')
      assert.are.equal(103, id) -- base 100 + col 3
    end)

    it('should produce deterministic IDs for lnum group', function()
      local extmark = Extmark(0)
      local id = extmark:derive_id(7, 'lnum')
      assert.are.equal(1007, id) -- base 1000 + col 7
    end)

    it('should produce different IDs for different cols', function()
      local extmark = Extmark(0)
      local id1 = extmark:derive_id(0, 'text')
      local id2 = extmark:derive_id(1, 'text')
      assert.are_not.equal(id1, id2)
    end)

    it('should produce different IDs for different groups', function()
      local extmark = Extmark(0)
      local id_text = extmark:derive_id(5, 'text')
      local id_sign = extmark:derive_id(5, 'sign')
      local id_lnum = extmark:derive_id(5, 'lnum')
      assert.are_not.equal(id_text, id_sign)
      assert.are_not.equal(id_sign, id_lnum)
      assert.are_not.equal(id_text, id_lnum)
    end)

    it('should error on invalid group name', function()
      local extmark = Extmark(0)
      assert.has_error(function()
        extmark:derive_id(0, 'invalid')
      end, 'invalid extmark group')
    end)

    it('should handle col 0', function()
      local extmark = Extmark(0)
      assert.are.equal(10, extmark:derive_id(0, 'text'))
      assert.are.equal(100, extmark:derive_id(0, 'sign'))
      assert.are.equal(1000, extmark:derive_id(0, 'lnum'))
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
