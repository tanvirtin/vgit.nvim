local fs = require('vgit.core.fs')
local spy = require('luassert.spy')
local Window = require('vgit.core.Window')
local Buffer = require('vgit.core.Buffer')
local renderer = require('vgit.core.renderer')

local eq = assert.are.same

describe('Buffer:', function()
  local bufnr
  local buffer

  before_each(function()
    bufnr = vim.api.nvim_create_buf(false, true)
    buffer = Buffer(bufnr)
  end)

  describe('constructor', function()
    it('should initialize buffer with a buffer number', function()
      eq(buffer.bufnr, bufnr)
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

      eq(on_render, buffer.on_render)
      assert.is_true(buffer._is_attached_to_screen)
      assert.is_true(renderer.buffers[bufnr] ~= nil)
    end)
  end)

  describe('detach_from_renderer', function()
    it('should detach from renderer', function()
      buffer:attach_to_renderer(function() end)
      buffer:detach_from_renderer()

      eq(renderer.buffers[bufnr], nil)
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
      buffer.on_render = spy.new(function() end)
      buffer.on_render(top, bot)
      assert.spy(buffer.on_render).was.called_with(top, bot)
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

  describe('get_relative_name', function()
    it('should return empty string for unnamed buffer', function()
      local unnamed_buf = Buffer(vim.api.nvim_create_buf(false, true))
      assert.are.equal('', unnamed_buf:get_relative_name())
    end)

    it('should return relative name for named buffer', function()
      local named_buf = Buffer(vim.api.nvim_create_buf(false, true))
      vim.api.nvim_buf_set_name(named_buf.bufnr, vim.loop.cwd() .. '/lua/vgit/init.lua')
      assert.are.equal('lua/vgit/init.lua', named_buf:get_relative_name())
    end)
  end)

  describe('create', function()
    it('should create a new buffer with valid bufnr', function()
      buffer = Buffer():create(false, true)

      -- Verify buffer was created with a valid ID
      assert.is_number(buffer.bufnr, 'bufnr should be a number')
      assert.is_true(buffer.bufnr > 0, 'bufnr should be positive')
      assert.are_not.same(buffer.bufnr, bufnr, 'new buffer should have different ID')

      -- Verify the buffer actually exists in Neovim
      assert.is_true(vim.api.nvim_buf_is_valid(buffer.bufnr), 'buffer should exist in Neovim')
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
      buffer:delete()
      assert.is_false(buffer:is_valid())
    end)
  end)

  describe('get_lines', function()
    it('should get buffer lines', function()
      vim.api.nvim_buf_set_lines(buffer.bufnr, 0, -1, false, { 'line1', 'line2' })
      eq(buffer:get_lines(), { 'line1', 'line2' })
    end)
  end)

  describe('set_lines', function()
    it('should set buffer lines', function()
      buffer:set_lines({ 'line1', 'line2' })
      eq(buffer:get_lines(), { 'line1', 'line2' })
    end)
  end)

  describe('set_option', function()
    it('should set buffer option', function()
      vim.api.nvim_set_option_value('ft', 'lua', { buf = buffer.bufnr })
      assert.equals(buffer:get_option('ft'), 'lua')
    end)

    it('should track modifiable state', function()
      buffer:set_option('modifiable', false)
      assert.is_false(buffer._modifiable)

      buffer:set_option('modifiable', true)
      assert.is_true(buffer._modifiable)
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

    it('should track modifiable when assigned', function()
      buffer:assign_options({ modifiable = false })
      assert.is_false(buffer._modifiable)
    end)
  end)

  describe('modifiable caching in set_lines', function()
    it('should use cached modifiable state', function()
      -- Set modifiable to true explicitly
      buffer:set_option('modifiable', true)
      assert.is_true(buffer._modifiable)

      -- set_lines should work without calling nvim_buf_get_option
      buffer:set_lines({ 'test' })
      eq({ 'test' }, buffer:get_lines())
    end)

    it('should handle non-modifiable buffer via cache', function()
      buffer:set_option('modifiable', false)
      assert.is_false(buffer._modifiable)

      -- set_lines should toggle modifiable around the set_lines call
      buffer:set_lines({ 'test' })
      eq({ 'test' }, buffer:get_lines())
    end)

    it('should lazily determine modifiable when not cached', function()
      -- _modifiable starts as nil
      assert.is_nil(buffer._modifiable)

      -- set_lines should query and cache
      buffer:set_lines({ 'hello' })
      assert.is_not_nil(buffer._modifiable)
      eq({ 'hello' }, buffer:get_lines())
    end)
  end)

  describe('get_line_count', function()
    it('should get buffer line count', function()
      buffer:set_lines({ 'line1', 'line2' })
      assert.equals(buffer:get_line_count(), 2)
    end)
  end)

  describe('is_modified', function()
    it('should return false for non-modified buffer', function()
      assert.is_false(buffer:is_modified())
    end)
  end)

  describe('get_filetype', function()
    it('should return detected filetype for named buffer', function()
      vim.api.nvim_buf_set_name(buffer.bufnr, 'test_file.lua')
      local ft = buffer:get_filetype()
      assert.are.equal('lua', ft)
    end)
  end)

  describe('set_keymap', function()
    it('should register a keymap on the buffer', function()
      buffer:set_keymap({
        mode = 'n',
        key = 'gz',
        desc = 'test keymap',
      }, function() end)

      local keymaps = vim.api.nvim_buf_get_keymap(buffer.bufnr, 'n')
      local found = false
      for _, km in ipairs(keymaps) do
        if km.lhs == 'gz' then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)
  end)

  describe('place_extmark_sign', function()
    it('should place a sign extmark on valid buffer', function()
      buffer:set_lines({ 'test line' })

      buffer:place_extmark_sign({
        row = 0,
        name = 'GitSignsAdd',
      })

      local ns_id = buffer._sign_extmark.ns_id
      local extmarks = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns_id, 0, -1, {})
      assert.is_true(#extmarks > 0)
    end)
  end)

  describe('clear_extmarks', function()
    it('should clear all extmarks from the buffer', function()
      buffer:set_lines({ 'test line' })

      buffer:place_extmark_sign({ row = 0, name = 'GitSignsAdd' })
      local ns_id = buffer._sign_extmark.ns_id
      local before = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns_id, 0, -1, {})
      assert.is_true(#before > 0)

      buffer:clear_extmarks()

      local after = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #after)
    end)
  end)

  describe('clear_extmark_signs', function()
    it('should clear sign extmarks from the buffer', function()
      buffer:set_lines({ 'test line' })

      buffer:place_extmark_sign({ row = 0, name = 'GitSignsAdd' })
      local ns_id = buffer._sign_extmark.ns_id
      local before = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns_id, 0, -1, {})
      assert.is_true(#before > 0)

      buffer:clear_extmark_signs()

      local after = vim.api.nvim_buf_get_extmarks(buffer.bufnr, ns_id, 0, -1, {})
      assert.are.equal(0, #after)
    end)
  end)

  describe('set_var', function()
    it('should set buffer variable', function()
      buffer:set_var('vgit_status', {
        added = 0,
        changed = 0,
        removed = 0,
      })
      eq(vim.api.nvim_buf_get_var(buffer.bufnr, 'vgit_status'), {
        added = 0,
        changed = 0,
        removed = 0,
      })
    end)
  end)
end)
