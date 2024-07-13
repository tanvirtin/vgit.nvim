local fs = require('vgit.core.fs')
local spy = require('luassert.spy')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local renderer = require('vgit.core.renderer')

describe('Buffer', function()
  local bufnr
  local buffer

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    buffer = Buffer(bufnr)
  end)

  describe('constructor', function()
    it('should initialize buffer with a buffer number', function()
      assert.are.same(buffer.bufnr, bufnr)
      assert.is_not_nil(buffer.watcher)
      assert.is_not_nil(buffer.namespace)
    end)
  end)

  describe('call', function()
    it('should call the callback within the buffer context', function()
      local callback = spy.new(function() end)
      buffer:call(callback)

      assert.spy(callback).was.called(1)
    end)
  end)

  describe('attach_to_changes', function()
    it('should attach to buffer changes', function()
      local callback = spy.new(function() end)
      buffer:attach_to_changes({
        on_lines = function()
          callback()
        end,
      })
      buffer:set_lines({ 'sup' })

      assert.spy(callback).was.called(1)
    end)
  end)

  describe('attach_to_renderer', function()
    it('should attach to renderer', function()
      local on_render = function() end
      buffer:attach_to_renderer(on_render)

      assert.are.same(on_render, buffer.state.on_render)
      assert.is_true(buffer.state.is_attached_to_screen)
      assert.is_true(renderer.buffers[bufnr] ~= nil)
    end)
  end)

  describe('detach_from_renderer', function()
    it('should detach from renderer', function()
      buffer:attach_to_renderer(function() end)
      buffer:detach_from_renderer()

      assert.are.same(renderer.buffers[bufnr], nil)
    end)
  end)

  describe('on', function()
    it('should register an event callback', function()
      local works = false
      local callback = function()
        works = true
      end
      local window = Window(0):open(buffer, {
        relative = 'editor',
        width = 20,
        height = 10,
        row = 5,
        col = 5,
      })
      buffer:on('WinEnter', callback)
      window:focus()

      assert(works)
    end)
  end)

  describe('on_render', function()
    it('should call on_render function with correct parameters', function()
      local top, bot = 1, 10
      buffer.state.on_render = spy.new(function() end)
      buffer:on_render(top, bot)
      assert.spy(buffer.state.on_render).was.called_with(top, bot)
    end)
  end)

  describe('is_in_disk', function()
    it('should return if buffer is in disk', function()
      local exists = spy.on(fs, 'exists')
      buffer:is_in_disk()
      assert.spy(exists).was.called(1)
    end)
  end)

  describe('get_name', function()
    it('should return buffer name', function()
      vim.api.nvim_buf_set_name(bufnr, 'test')
      assert.equals(buffer:get_name(), string.format('%s/test', vim.loop.cwd()))
    end)
  end)

  describe('add_highlight', function()
    it('should add highlight to buffer', function()
      buffer:set_lines({ 'hello world', 'foo bar' })
      local ok, extmark_id = buffer:add_highlight({
        hl = 'Error',
        row = 1,
        col_range = { from = 1, to = 2 },
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
    end)
  end)

  describe('add_pattern_highlight', function()
    it('should add pattern highlight to buffer', function()
      buffer:set_lines({ 'Hello | World' })
      local ok, extmark_ids = buffer:add_pattern_highlight('pattern', 'Error')
      assert.is_true(ok)
      assert.is_not_nil(extmark_ids)
      for i = 1, #extmark_ids do
        local extmark_id = extmark_ids[i]
        local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, buffer.namespace.ns_id, extmark_id, {})
        assert.are.same(extmark, { 0, 6 })
      end
    end)
  end)

  describe('transpose_virtual_text', function()
    it('should transpose virtual text in buffer', function()
      buffer:set_lines({ 'Hello World' })
      local ok, extmark_id = buffer:transpose_virtual_text({
        text = 'virtual',
        hl = 'Error',
        row = 0,
        col = 3,
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
    end)
  end)

  describe('transpose_virtual_line', function()
    it('should transpose virtual line in buffer', function()
      buffer:set_lines({ 'Hello World' })
      local ok, extmark_id = buffer:transpose_virtual_line({
        row = 0,
        texts = { { 'virtual', 'Error' } },
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
    end)
  end)

  describe('transpose_virtual_line_number', function()
    it('should transpose virtual line number in buffer', function()
      buffer:set_lines({ 'Hello World', 'sup' })
      local ok, extmark_id = buffer:transpose_virtual_line_number({
        text = 'virtual',
        hl = 'Error',
        row = 1,
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
    end)
  end)

  describe('insert_virtual_line', function()
    it('should insert virtual line in buffer', function()
      buffer:set_lines({ 'Hello World', 'foo', 'bar' })
      local ok, extmark_id = buffer:insert_virtual_line({
        text = 'virtual',
        hl = 'Error',
        row = 2,
      })
      assert.is_true(ok)
      assert.is_not_nil(extmark_id)
    end)
  end)

  describe('clear_namespace', function()
    it('should clear highlight from buffer', function()
      buffer:set_lines({ 'Hello World', 'foo', 'bar' })
      local _, extmark_id = buffer:insert_virtual_line({
        text = 'virtual',
        hl = 'Error',
        row = 2,
      })
      local success = buffer:clear_namespace()
      assert.is_true(success)
      local extmark = vim.api.nvim_buf_get_extmark_by_id(buffer.bufnr, buffer.namespace.ns_id, extmark_id, {})
      assert.are.same(extmark, {})
    end)
  end)

  describe('create', function()
    it('should create a new buffer', function()
      buffer = Buffer():create(false, true)
      assert.is_not_nil(buffer.bufnr)
      assert.is_not.same(buffer.bufnr, bufnr)
    end)
  end)

  describe('is_current', function()
    it('should return if buffer is current', function()
      local other_buffer = Buffer():create(false, true)
      local window = Window(0):open(buffer, {
        relative = 'editor',
        width = 20,
        height = 10,
        row = 5,
        col = 5,
      })
      window:focus()
      assert.is_true(buffer:is_current())
      assert.is_false(other_buffer:is_current())
    end)
  end)

  describe('is_valid', function()
    it('should return if buffer is valid', function()
      assert.is_true(buffer:is_valid())
      vim.api.nvim_buf_delete(buffer.bufnr, { force = true })
      assert.is_false(buffer:is_valid())
    end)
  end)

  describe('delete', function()
    it('should delete buffer', function()
      assert.is_true(buffer:is_valid())
      vim.api.nvim_buf_delete(buffer.bufnr, { force = true })
      assert.is_false(buffer:is_valid())
    end)
  end)

  describe('get_lines', function()
    it('should get buffer lines', function()
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'line1', 'line2' })
      assert.are.same(buffer:get_lines(), { 'line1', 'line2' })
    end)
  end)

  describe('set_lines', function()
    it('should set buffer lines', function()
      buffer:set_lines({ 'line1', 'line2' })
      assert.are.same(buffer:get_lines(), { 'line1', 'line2' })
    end)
  end)

  describe('set_option', function()
    it('should set buffer option', function()
      vim.api.nvim_buf_set_option(buffer.bufnr, 'ft', 'lua')
      assert.equals(buffer:get_option('ft'), 'lua')
    end)
  end)

  describe('get_option', function()
    it('should get buffer option', function()
      buffer:set_option('ft', 'lua')
      assert.equals(buffer:get_option('ft'), 'lua')
    end)
  end)

  describe('assign_options', function()
    it('should assign multiple buffer options', function()
      buffer:assign_options({
        ft = 'lua',
        bufhidden = 'wipe',
      })
      assert.equals(buffer:get_option('ft'), 'lua')
      assert.equals(buffer:get_option('bufhidden'), 'wipe')
    end)
  end)

  describe('get_line_count', function()
    it('should get buffer line count', function()
      buffer:set_lines({ 'line1', 'line2' })
      assert.equals(buffer:get_line_count(), 2)
    end)
  end)

  describe('list', function()
    it('should list all buffers', function()
      local buffers = buffer:list()
      assert.is_true(#buffers > 0)
      for i = 1, #buffers do
        buffer = buffers[i]
        buffer:delete()
      end
      assert.are.same(#buffer:list(), 1)
    end)
  end)

  describe('set_var', function()
    it('should set buffer variable', function()
      buffer:set_var('vgit_status', {
        added = 0,
        changed = 0,
        removed = 0,
      })
      assert.are.same(vim.api.nvim_buf_get_var(buffer.bufnr, 'vgit_status'), {
        added = 0,
        changed = 0,
        removed = 0,
      })
    end)
  end)
end)
