local sign = require('vgit.core.sign')
local Buffer = require('vgit.core.Buffer')
local highlight = require('vgit.core.highlight')
local Namespace = require('vgit.core.Namespace')

describe('Namespace', function()
  local namespace
  local buffer = Buffer(0)

  highlight.register_module(function()
    sign.register_module()
  end)

  before_each(function()
    namespace = Namespace()
  end)

  describe('constructor', function()
    it('should create a new namespace with a unique ID', function()
      assert.is_number(namespace.ns_id)
    end)
  end)

  describe('get_sign_ns_id', function()
    it('should return the correct sign namespace ID for a buffer', function()
      local sign_ns_id = namespace:get_sign_ns_id(buffer)
      assert.equals('tanvirtin/vgit.nvim/hunk/signs/' .. buffer.bufnr, sign_ns_id)
    end)
  end)

  describe('add_highlight', function()
    it('should add a highlight to a buffer', function()
      buffer:set_lines({ 'hello world', 'foo bar' })
      local ok, extmark_id = namespace:add_highlight(buffer, {
        hl = 'Error',
        row = 1,
        col_range = { from = 1, to = 2 },
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, { 1, 1 })
    end)
  end)

  describe('add_pattern_highlight', function()
    it('should add highlights based on pattern', function()
      buffer:set_lines({ 'Hello | World' })
      local ok, extmark_ids = namespace:add_pattern_highlight(buffer, '|', 'Error')
      assert.is_true(ok)
      assert.is_not_nil(extmark_ids)
      for i = 1, #extmark_ids do
        local extmark_id = extmark_ids[i]
        local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
        assert.are.same(extmark, { 0, 6 })
      end
    end)
  end)

  describe('transpose_virtual_text', function()
    it('should add virtual text to a buffer', function()
      buffer:set_lines({ 'Hello World' })
      local success, extmark_id = namespace:transpose_virtual_text(buffer, {
        text = 'virtual',
        hl = 'Error',
        row = 0,
        col = 3,
      })
      assert.is_true(success)
      assert.is_number(extmark_id)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, { 0, 3 })
    end)
  end)

  describe('transpose_virtual_line', function()
    it('should add virtual lines to a buffer', function()
      buffer:set_lines({ 'Hello World' })
      local success, extmark_id = namespace:transpose_virtual_line(buffer, {
        row = 0,
        texts = { { 'virtual', 'Error' } },
      })
      assert.is_true(success)
      assert.is_number(extmark_id)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, { 0, 0 })
    end)
  end)

  describe('transpose_virtual_line_number', function()
    it('should add virtual line numbers to a buffer', function()
      buffer:set_lines({ 'Hello World', 'sup' })
      local opts = {}
      local success, extmark_id = namespace:transpose_virtual_line_number(buffer, {
 text = 'virtual',
 hl = 'Error',
 row = 1
      })
      assert.is_true(success)
      assert.is_number(extmark_id)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, { 1, 0 })
    end)
  end)

  describe('insert_virtual_line', function()
    it('should insert virtual lines above a row in a buffer', function()
      buffer:set_lines({ 'Hello World', 'foo', 'bar' })
      local success, extmark_id = namespace:insert_virtual_line(buffer, {
        text = 'virtual',
        hl = 'Error',
        row = 2,
      })
      assert.is_true(success)
      assert.is_number(extmark_id)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, { 2, 0 })
    end)
  end)

  describe('clear', function()
    it('should clear highlights from the buffer', function()
      buffer:set_lines({ 'Hello World', 'foo', 'bar' })
      local _, extmark_id = namespace:insert_virtual_line(buffer, {
        text = 'virtual',
        hl = 'Error',
        row = 2,
      })
      local success = namespace:clear(buffer)
      assert.is_true(success)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, {})
    end)
  end)

  describe('sign_place', function()
    it('should place a sign in the buffer', function()
      local success = namespace:sign_place(buffer, 1, 'GitSignsAdd')
      assert.is_true(success)
    end)
  end)

  describe('sign_unplace', function()
    it('should remove a sign from the buffer', function()
      namespace:sign_place(buffer, 1, 'GitSignsAdd')
      local success = namespace:sign_unplace(buffer, 1)
      assert.is_true(success)
    end)
  end)
end)
