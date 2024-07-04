local sign = require('vgit.core.sign')
local Buffer = require('vgit.core.Buffer')
local highlight = require('vgit.core.highlight')
local Namespace = require('vgit.core.Namespace')

describe('Namespace', function()
  local buffer = Buffer(0)

  highlight.register_module(function()
    sign.register_module()
  end)

  describe('constructor', function()
    it('should create a new namespace with a unique ID', function()
      local namespace = Namespace()
      assert.is_number(namespace.ns_id)
    end)
  end)

  describe('get_sign_ns_id', function()
    it('should return the correct sign namespace ID for a buffer', function()
      local namespace = Namespace()
      local sign_ns_id = namespace:get_sign_ns_id(buffer)
      assert.equals('tanvirtin/vgit.nvim/hunk/signs/' .. buffer.bufnr, sign_ns_id)
    end)
  end)

  describe('add_highlight', function()
    it('should add a highlight to a buffer', function()
      local namespace = Namespace()
      local opts = { hl = 'Error', row = 0, col_range = { from = 0, to = 1 } }
      local success = namespace:add_highlight(buffer, opts)
      assert.is_true(success)
    end)
  end)

  describe('add_pattern_highlight', function()
    it('should add highlights based on pattern', function()
      local namespace = Namespace()
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'test pattern' })
      local success = namespace:add_pattern_highlight(buffer, 'pattern', 'Error')
      assert.is_true(success)
    end)
  end)

  describe('transpose_virtual_text', function()
    it('should add virtual text to a buffer', function()
      local namespace = Namespace()
      local opts = { text = 'virtual', hl = 'Error', row = 0, col = 0 }
      local success, id = namespace:transpose_virtual_text(buffer, opts)
      assert.is_true(success)
      assert.is_number(id)
    end)
  end)

  describe('transpose_virtual_line', function()
    it('should add virtual lines to a buffer', function()
      local namespace = Namespace()
      local opts = { texts = { { 'virtual', 'Error' } }, row = 0 }
      local success, id = namespace:transpose_virtual_line(buffer, opts)
      assert.is_true(success)
      assert.is_number(id)
    end)
  end)

  describe('transpose_virtual_line_number', function()
    it('should add virtual line numbers to a buffer', function()
      local namespace = Namespace()
      local opts = { text = 'virtual', hl = 'Error', row = 0 }
      local success, id = namespace:transpose_virtual_line_number(buffer, opts)
      assert.is_true(success)
      assert.is_number(id)
    end)
  end)

  describe('insert_virtual_line', function()
    it('should insert virtual lines above a row in a buffer', function()
      local namespace = Namespace()
      local opts = { text = 'virtual', hl = 'Error', row = 0 }
      local success, id = namespace:insert_virtual_line(buffer, opts)
      assert.is_true(success)
      assert.is_number(id)
    end)
  end)

  describe('sign_place', function()
    it('should place a sign in the buffer', function()
      local namespace = Namespace()
      local success = namespace:sign_place(buffer, 1, 'GitSignsAdd')
      assert.is_true(success)
    end)
  end)

  describe('sign_unplace', function()
    it('should remove a sign from the buffer', function()
      local namespace = Namespace()
      namespace:sign_place(buffer, 1, 'GitSignsAdd')
      local success = namespace:sign_unplace(buffer, 1)
      assert.is_true(success)
    end)
  end)

  describe('clear', function()
    it('should clear highlights from the buffer', function()
      local namespace = Namespace()
      local success = namespace:clear(buffer)
      assert.is_true(success)
    end)
  end)
end)