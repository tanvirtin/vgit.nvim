local SyntaxAnnotator = require('vgit.ui.annotators.SyntaxAnnotator')

local eq = assert.are.same

describe('SyntaxAnnotator:', function()
  local annotator

  before_each(function()
    annotator = SyntaxAnnotator()
  end)

  describe('_cache_key', function()
    it('should generate key from filetype and content', function()
      local key = annotator:_cache_key({ 'line1', 'line2', 'line3' }, 'lua')
      assert.is_truthy(key)
      assert.is_truthy(key:match('lua'))
      assert.is_truthy(key:match('3'))
    end)

    it('should return nil for empty lines', function()
      local key = annotator:_cache_key({}, 'lua')
      eq(nil, key)
    end)

    it('should generate different keys for different content', function()
      local key1 = annotator:_cache_key({ 'aaa', 'bbb' }, 'lua')
      local key2 = annotator:_cache_key({ 'xxx', 'yyy' }, 'lua')
      assert.are_not.equal(key1, key2)
    end)

    it('should generate different keys for different filetypes', function()
      local key1 = annotator:_cache_key({ 'line1' }, 'lua')
      local key2 = annotator:_cache_key({ 'line1' }, 'python')
      assert.are_not.equal(key1, key2)
    end)

    it('should sample quartile lines for collision resistance', function()
      local lines1 = { 'start', 'a', 'b', 'c', 'd', 'e', 'f', 'g', 'end' }
      local lines2 = { 'start', 'x', 'y', 'z', 'w', 'v', 'u', 't', 'end' }
      local key1 = annotator:_cache_key(lines1, 'lua')
      local key2 = annotator:_cache_key(lines2, 'lua')
      assert.are_not.equal(key1, key2)
    end)

    it('should handle single-line input', function()
      local key = annotator:_cache_key({ 'only line' }, 'lua')
      assert.is_truthy(key)
      assert.is_truthy(key:match('lua'))
    end)
  end)

  describe('clear_cache', function()
    it('should clear the cache and order', function()
      annotator:_cache_put('key1', { 'data' })
      annotator:_cache_put('key2', { 'data2' })
      annotator:clear_cache()
      eq({}, annotator._cache)
      eq({}, annotator._cache_order)
    end)
  end)

  describe('_cache_put', function()
    it('should store value in cache', function()
      annotator:_cache_put('key1', { 'highlights' })
      eq({ 'highlights' }, annotator._cache['key1'])
    end)

    it('should evict oldest entry when cache exceeds max (FIFO)', function()
      annotator._cache_max = 2
      annotator:_cache_put('key1', { 'a' })
      annotator:_cache_put('key2', { 'b' })
      eq({ 'a' }, annotator._cache['key1'])
      eq({ 'b' }, annotator._cache['key2'])

      annotator:_cache_put('key3', { 'c' })
      eq(nil, annotator._cache['key1'])
      eq({ 'b' }, annotator._cache['key2'])
      eq({ 'c' }, annotator._cache['key3'])
    end)

    it('should not duplicate key in order when updating existing entry', function()
      annotator._cache_max = 3
      annotator:_cache_put('key1', { 'a' })
      annotator:_cache_put('key2', { 'b' })
      annotator:_cache_put('key1', { 'a_updated' })

      eq({ 'a_updated' }, annotator._cache['key1'])
      eq(2, #annotator._cache_order)
    end)

    it('should maintain FIFO order across multiple evictions', function()
      annotator._cache_max = 2
      annotator:_cache_put('key1', { 'a' })
      annotator:_cache_put('key2', { 'b' })
      annotator:_cache_put('key3', { 'c' })
      annotator:_cache_put('key4', { 'd' })

      eq(nil, annotator._cache['key1'])
      eq(nil, annotator._cache['key2'])
      eq({ 'c' }, annotator._cache['key3'])
      eq({ 'd' }, annotator._cache['key4'])
    end)
  end)

  describe('annotate', function()
    it('should return empty table for nil lines', function()
      eq({}, annotator:annotate(nil, 'lua'))
    end)

    it('should return empty table for empty lines', function()
      eq({}, annotator:annotate({}, 'lua'))
    end)

    it('should return empty table for nil filetype', function()
      eq({}, annotator:annotate({ 'local x = 1' }, nil))
    end)

    it('should return empty table for empty filetype', function()
      eq({}, annotator:annotate({ 'local x = 1' }, ''))
    end)

    it('should return empty table for text filetype', function()
      eq({}, annotator:annotate({ 'local x = 1' }, 'text'))
    end)

    it('should return cached result on second call with same input', function()
      local sentinel = { { row = 0, col_start = 0, col_end = 1, hl_group = '@test' } }
      local lines = { 'local x = 1' }
      local key = annotator:_cache_key(lines, 'lua')
      annotator:_cache_put(key, sentinel)

      local result = annotator:annotate(lines, 'lua')
      eq(sentinel, result)
    end)
  end)

  describe('_parse_highlights', function()
    it('should return empty table when parser unavailable', function()
      local bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'test' })

      local highlights = annotator:_parse_highlights(bufnr, 'nonexistent_filetype_xyz')
      eq({}, highlights)

      vim.api.nvim_buf_delete(bufnr, { force = true })
    end)
  end)
end)
