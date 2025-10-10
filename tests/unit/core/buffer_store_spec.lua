local Buffer = require('vgit.core.Buffer')
local buffer_store = require('vgit.core.buffer_store')

describe('buffer_store:', function()
  describe('list', function()
    it('should return a list of Buffer objects', function()
      local buffers = buffer_store.list()

      assert.is_table(buffers)
      assert.is_true(#buffers >= 0)
    end)

    it('should wrap all buffers from nvim_list_bufs', function()
      local test_bufnr1 = vim.api.nvim_create_buf(false, true)
      local test_bufnr2 = vim.api.nvim_create_buf(false, true)

      local buffers = buffer_store.list()

      local found_buf1 = false
      local found_buf2 = false

      for i = 1, #buffers do
        local buffer = buffers[i]
        if buffer.bufnr == test_bufnr1 then found_buf1 = true end
        if buffer.bufnr == test_bufnr2 then found_buf2 = true end
      end

      vim.api.nvim_buf_delete(test_bufnr1, { force = true })
      vim.api.nvim_buf_delete(test_bufnr2, { force = true })

      assert.is_true(found_buf1)
      assert.is_true(found_buf2)
    end)

    it('should return Buffer instances with correct metatable', function()
      local test_bufnr = vim.api.nvim_create_buf(false, true)

      local buffers = buffer_store.list()

      local test_buffer = nil
      for i = 1, #buffers do
        if buffers[i].bufnr == test_bufnr then
          test_buffer = buffers[i]
          break
        end
      end

      vim.api.nvim_buf_delete(test_bufnr, { force = true })

      assert.is_truthy(test_buffer, 'should find the created buffer in the list')
      assert.is_true(test_buffer:is(Buffer), 'should be a Buffer instance')

      assert.equals(test_buffer.bufnr, test_bufnr)
    end)

    it('should return correct number of buffers', function()
      local initial_count = #buffer_store.list()

      local test_bufnr = vim.api.nvim_create_buf(false, true)

      local new_count = #buffer_store.list()

      vim.api.nvim_buf_delete(test_bufnr, { force = true })

      assert.are.equal(new_count, initial_count + 1)
    end)

    it('should handle empty buffer list gracefully', function()
      local original_list_bufs = vim.api.nvim_list_bufs

      vim.api.nvim_list_bufs = function()
        return {}
      end

      local buffers = buffer_store.list()

      vim.api.nvim_list_bufs = original_list_bufs

      assert.are.same(buffers, {})
    end)

    it('should create Buffer objects with valid bufnr property', function()
      local buffers = buffer_store.list()

      for i = 1, #buffers do
        local buffer = buffers[i]
        assert.is_number(buffer.bufnr)
        assert.is_true(buffer.bufnr >= 0)
      end
    end)
  end)
end)
