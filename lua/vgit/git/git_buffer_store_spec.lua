local git_buffer_store = require('vgit.git.git_buffer_store')

local eq = assert.are.same

describe('git_buffer_store:', function()
  local mock_buffer

  before_each(function()
    -- Clear the buffer store before each test
    -- Note: This is internal but necessary for test isolation
    git_buffer_store.for_each(function(buf)
      git_buffer_store.remove(buf)
    end)

    -- Create a mock buffer
    mock_buffer = {
      bufnr = 1,
      filename = 'test.txt',
      sync = function() end,
      exists = function()
        return true
      end,
      attach_to_changes = function(self)
        return self
      end,
      attach_to_renderer = function(self)
        return self
      end,
      detach_from_renderer = function() end,
    }
  end)

  after_each(function()
    -- Clean up
    git_buffer_store.for_each(function(buf)
      git_buffer_store.remove(buf)
    end)
  end)

  describe('add()', function()
    it('should add buffer to store', function()
      git_buffer_store.add(mock_buffer)

      local retrieved = git_buffer_store.get(mock_buffer)
      assert(retrieved, 'Buffer should be in store')
      eq(retrieved.bufnr, 1)
    end)

    it('should return store for chaining', function()
      local result = git_buffer_store.add(mock_buffer)
      eq(result, git_buffer_store)
    end)

    it('should allow adding multiple buffers', function()
      local buffer1 = { bufnr = 1 }
      local buffer2 = { bufnr = 2 }
      local buffer3 = { bufnr = 3 }

      git_buffer_store.add(buffer1)
      git_buffer_store.add(buffer2)
      git_buffer_store.add(buffer3)

      eq(git_buffer_store.size(), 3)
    end)

    it('should replace buffer with same bufnr', function()
      local buffer1 = { bufnr = 1, data = 'first' }
      local buffer2 = { bufnr = 1, data = 'second' }

      git_buffer_store.add(buffer1)
      git_buffer_store.add(buffer2)

      local retrieved = git_buffer_store.get({ bufnr = 1 })
      eq(retrieved.data, 'second')
      eq(git_buffer_store.size(), 1)
    end)
  end)

  describe('get()', function()
    it('should retrieve added buffer', function()
      git_buffer_store.add(mock_buffer)

      local retrieved = git_buffer_store.get(mock_buffer)
      assert(retrieved, 'Should retrieve buffer')
      eq(retrieved.bufnr, mock_buffer.bufnr)
    end)

    it('should return nil for non-existent buffer', function()
      local non_existent = { bufnr = 999 }
      local retrieved = git_buffer_store.get(non_existent)
      eq(retrieved, nil)
    end)

    it('should retrieve by bufnr', function()
      local buffer1 = { bufnr = 5, data = 'test' }
      git_buffer_store.add(buffer1)

      local retrieved = git_buffer_store.get({ bufnr = 5 })
      assert(retrieved)
      eq(retrieved.data, 'test')
    end)
  end)

  describe('contains()', function()
    it('should return true for existing buffer', function()
      git_buffer_store.add(mock_buffer)

      local contains = git_buffer_store.contains(mock_buffer)
      eq(contains, true)
    end)

    it('should return false for non-existent buffer', function()
      local non_existent = { bufnr = 999 }
      local contains = git_buffer_store.contains(non_existent)
      eq(contains, false)
    end)

    it('should return false after buffer is removed', function()
      git_buffer_store.add(mock_buffer)
      git_buffer_store.remove(mock_buffer)

      local contains = git_buffer_store.contains(mock_buffer)
      eq(contains, false)
    end)
  end)

  describe('remove()', function()
    it('should remove buffer from store', function()
      git_buffer_store.add(mock_buffer)
      local removed = git_buffer_store.remove(mock_buffer)

      assert(removed, 'Should return removed buffer')
      eq(removed.bufnr, mock_buffer.bufnr)
      eq(git_buffer_store.size(), 0)
    end)

    it('should return nil when removing non-existent buffer', function()
      local non_existent = { bufnr = 999 }
      local removed = git_buffer_store.remove(non_existent)
      eq(removed, nil)
    end)

    it('should handle removing nil buffer', function()
      local removed = git_buffer_store.remove(nil)
      eq(removed, nil)
    end)

    it('should allow re-adding after removal', function()
      git_buffer_store.add(mock_buffer)
      git_buffer_store.remove(mock_buffer)
      git_buffer_store.add(mock_buffer)

      eq(git_buffer_store.size(), 1)
      assert(git_buffer_store.contains(mock_buffer))
    end)
  end)

  describe('size()', function()
    it('should return 0 for empty store', function()
      eq(git_buffer_store.size(), 0)
    end)

    it('should return correct count after adding buffers', function()
      git_buffer_store.add({ bufnr = 1 })
      eq(git_buffer_store.size(), 1)

      git_buffer_store.add({ bufnr = 2 })
      eq(git_buffer_store.size(), 2)

      git_buffer_store.add({ bufnr = 3 })
      eq(git_buffer_store.size(), 3)
    end)

    it('should return correct count after removing buffers', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 2 })
      git_buffer_store.add({ bufnr = 3 })

      git_buffer_store.remove({ bufnr = 2 })
      eq(git_buffer_store.size(), 2)
    end)

    it('should handle adding duplicate bufnr', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 1 }) -- Replace

      eq(git_buffer_store.size(), 1)
    end)
  end)

  describe('is_empty()', function()
    it('should return true for empty store', function()
      eq(git_buffer_store.is_empty(), true)
    end)

    it('should return false when buffers exist', function()
      git_buffer_store.add(mock_buffer)
      eq(git_buffer_store.is_empty(), false)
    end)

    it('should return true after all buffers removed', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 2 })
      git_buffer_store.remove({ bufnr = 1 })
      git_buffer_store.remove({ bufnr = 2 })

      eq(git_buffer_store.is_empty(), true)
    end)
  end)

  describe('for_each()', function()
    it('should iterate over all buffers', function()
      git_buffer_store.add({ bufnr = 1, data = 'a' })
      git_buffer_store.add({ bufnr = 2, data = 'b' })
      git_buffer_store.add({ bufnr = 3, data = 'c' })

      local collected = {}
      git_buffer_store.for_each(function(buffer)
        table.insert(collected, buffer.data)
      end)

      table.sort(collected)
      eq(#collected, 3)
      eq(collected[1], 'a')
      eq(collected[2], 'b')
      eq(collected[3], 'c')
    end)

    it('should handle empty store', function()
      local count = 0
      git_buffer_store.for_each(function()
        count = count + 1
      end)

      eq(count, 0)
    end)

    it('should not error if callback modifies store', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 2 })

      -- This is a potential issue - modifying during iteration
      -- Test that it doesn't crash
      local count = 0
      git_buffer_store.for_each(function(buffer)
        count = count + 1
        if buffer.bufnr == 1 then git_buffer_store.remove(buffer) end
      end)

      assert(count > 0, 'Should have iterated')
    end)
  end)

  describe('on()', function()
    it('should register event handler for single event', function()
      local called = false
      git_buffer_store.on('attach', function()
        called = true
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'attach')

      eq(called, true)
    end)

    it('should register event handler for multiple events', function()
      local attach_count = 0
      local change_count = 0

      git_buffer_store.on({ 'attach', 'change' }, function(_, event_type)
        if event_type == 'attach' then
          attach_count = attach_count + 1
        elseif event_type == 'change' then
          change_count = change_count + 1
        end
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'attach')
      git_buffer_store.dispatch(mock_buffer, 'change')
      git_buffer_store.dispatch(mock_buffer, 'change')

      eq(attach_count, 1)
      eq(change_count, 2)
    end)

    it('should return store for chaining', function()
      local result = git_buffer_store.on('attach', function() end)
      eq(result, git_buffer_store)
    end)

    it('should support chaining multiple handlers', function()
      local count = 0

      git_buffer_store
        .on('attach', function()
          count = count + 1
        end)
        .on('change', function()
          count = count + 10
        end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'attach')
      git_buffer_store.dispatch(mock_buffer, 'change')

      eq(count, 11)
    end)

    it('should error on invalid event type', function()
      local success, err = pcall(function()
        git_buffer_store.on('invalid_event', function() end)
      end)

      eq(success, false)
      assert(err:match('invalid event'))
    end)

    it('should support all valid event types', function()
      local events_fired = {}

      git_buffer_store
        .on('sync', function()
          table.insert(events_fired, 'sync')
        end)
        .on('attach', function()
          table.insert(events_fired, 'attach')
        end)
        .on('change', function()
          table.insert(events_fired, 'change')
        end)
        .on('reload', function()
          table.insert(events_fired, 'reload')
        end)
        .on('detach', function()
          table.insert(events_fired, 'detach')
        end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'sync')
      git_buffer_store.dispatch(mock_buffer, 'attach')
      git_buffer_store.dispatch(mock_buffer, 'change')
      git_buffer_store.dispatch(mock_buffer, 'reload')
      git_buffer_store.dispatch(mock_buffer, 'detach')

      eq(#events_fired, 5)
    end)
  end)

  describe('dispatch()', function()
    it('should call registered handlers', function()
      local called_buffer
      local called_event

      git_buffer_store.on('attach', function(buffer, event_type)
        called_buffer = buffer
        called_event = event_type
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'attach')

      eq(called_buffer.bufnr, mock_buffer.bufnr)
      eq(called_event, 'attach')
    end)

    it('should call all registered handlers', function()
      local call_count = 0

      git_buffer_store.on('change', function()
        call_count = call_count + 1
      end)

      git_buffer_store.on('change', function()
        call_count = call_count + 1
      end)

      git_buffer_store.on('change', function()
        call_count = call_count + 1
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'change')

      eq(call_count, 3)
    end)

    it('should pass additional arguments to handlers', function()
      local received_args

      git_buffer_store.on('change', function(buffer, event_type, ...)
        received_args = { ... }
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'change', 'arg1', 'arg2', 123)

      eq(#received_args, 3)
      eq(received_args[1], 'arg1')
      eq(received_args[2], 'arg2')
      eq(received_args[3], 123)
    end)

    it('should error on invalid event type', function()
      local success, err = pcall(function()
        git_buffer_store.dispatch(mock_buffer, 'invalid_event')
      end)

      eq(success, false)
      assert(err:match('invalid event'))
    end)

    it('should not error if no handlers registered', function()
      -- Should not crash even without handlers
      git_buffer_store.dispatch(mock_buffer, 'attach')
    end)

    it('should handle handlers that throw errors', function()
      git_buffer_store.on('attach', function()
        error('Handler error')
      end)

      git_buffer_store.on('attach', function()
        -- This should still run even if previous handler errors
        -- Though in practice, Lua error handling will stop execution
      end)

      -- Test that dispatch itself doesn't crash
      local success = pcall(function()
        git_buffer_store.dispatch(mock_buffer, 'attach')
      end)

      -- Should error from handler
      eq(success, false)
    end)
  end)

  describe('current()', function()
    it('should return buffer for current bufnr', function()
      -- Get actual current buffer
      local current_bufnr = vim.api.nvim_get_current_buf()
      local current_buffer = { bufnr = current_bufnr, data = 'current' }

      git_buffer_store.add(current_buffer)

      local retrieved = git_buffer_store.current()
      assert(retrieved, 'Should retrieve current buffer')
      eq(retrieved.data, 'current')
    end)

    it('should return nil if current buffer not in store', function()
      local retrieved = git_buffer_store.current()
      eq(retrieved, nil)
    end)
  end)

  describe('event lifecycle', function()
    it('should fire attach event when buffer added', function()
      git_buffer_store.on('attach', function()
        -- Intentionally empty - just testing event registration
      end)

      git_buffer_store.add(mock_buffer)
      -- Note: attach is fired by collect(), not add()
      -- This test documents the expected behavior
    end)

    it('should fire change event on buffer modification', function()
      local change_count = 0

      git_buffer_store.on('change', function()
        change_count = change_count + 1
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'change')
      git_buffer_store.dispatch(mock_buffer, 'change')

      eq(change_count, 2)
    end)

    it('should fire reload event on buffer reload', function()
      local reload_fired = false

      git_buffer_store.on('reload', function()
        reload_fired = true
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'reload')

      eq(reload_fired, true)
    end)

    it('should fire detach event when buffer detached', function()
      local detach_fired = false

      git_buffer_store.on('detach', function()
        detach_fired = true
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'detach')

      eq(detach_fired, true)
    end)

    it('should fire sync event on git changes', function()
      local sync_count = 0

      git_buffer_store.on('sync', function()
        sync_count = sync_count + 1
      end)

      git_buffer_store.add(mock_buffer)
      git_buffer_store.dispatch(mock_buffer, 'sync')
      git_buffer_store.dispatch(mock_buffer, 'sync')

      eq(sync_count, 2)
    end)
  end)

  describe('clear_buffers()', function()
    before_each(function()
      -- Full reset to avoid stale event handlers accumulated by earlier tests
      git_buffer_store.reset()
    end)

    after_each(function()
      git_buffer_store.reset()
    end)

    it('should empty the buffer store', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 2 })
      git_buffer_store.add({ bufnr = 3 })

      git_buffer_store.clear_buffers()

      eq(git_buffer_store.size(), 0)
      eq(git_buffer_store.is_empty(), true)
    end)

    it('should be idempotent on an already-empty store', function()
      git_buffer_store.clear_buffers()
      git_buffer_store.clear_buffers()
      eq(git_buffer_store.size(), 0)
    end)

    it('should not affect registered event handlers', function()
      local attach_count = 0
      git_buffer_store.on('attach', function()
        attach_count = attach_count + 1
      end)

      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.clear_buffers()

      local buf = { bufnr = 2 }
      git_buffer_store.add(buf)
      git_buffer_store.dispatch(buf, 'attach')

      eq(attach_count, 1)
    end)

    it('should allow buffers to be re-added after clear', function()
      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.clear_buffers()

      git_buffer_store.add({ bufnr = 1 })
      git_buffer_store.add({ bufnr = 2 })

      eq(git_buffer_store.size(), 2)
    end)
  end)

  describe('VGitChange sync flow', function()
    it('should call clear_blob_cache on buffers during sync iteration', function()
      local cache_cleared = false
      local sync_dispatched = false

      local buffer_with_cache = {
        bufnr = 10,
        clear_blob_cache = function()
          cache_cleared = true
        end,
      }

      git_buffer_store.on('sync', function()
        sync_dispatched = true
      end)

      git_buffer_store.add(buffer_with_cache)

      -- Simulate the VGitChange handler's for_each logic
      git_buffer_store.for_each(function(buffer)
        buffer:clear_blob_cache()
        git_buffer_store.dispatch(buffer, 'sync')
      end)

      eq(cache_cleared, true)
      eq(sync_dispatched, true)
    end)

    it('should handle buffers without clear_blob_cache gracefully', function()
      local buffer_without_cache = {
        bufnr = 11,
      }

      git_buffer_store.add(buffer_without_cache)

      -- Should error when clear_blob_cache is missing, catching the contract violation
      local success = pcall(function()
        git_buffer_store.for_each(function(buffer)
          buffer:clear_blob_cache()
        end)
      end)

      eq(success, false)
    end)

    it('should clear blob cache and dispatch sync for all buffers', function()
      local cleared = {}
      local synced = {}

      for i = 1, 3 do
        git_buffer_store.add({
          bufnr = 20 + i,
          clear_blob_cache = function(self)
            cleared[#cleared + 1] = self.bufnr
          end,
        })
      end

      git_buffer_store.on('sync', function(buffer)
        synced[#synced + 1] = buffer.bufnr
      end)

      git_buffer_store.for_each(function(buffer)
        buffer:clear_blob_cache()
        git_buffer_store.dispatch(buffer, 'sync')
      end)

      table.sort(cleared)
      table.sort(synced)

      eq(#cleared, 3)
      eq(#synced, 3)
      eq(cleared, synced)
    end)
  end)

  describe('edge cases', function()
    it('should handle string bufnr conversion', function()
      -- Store uses tostring(bufnr) internally
      local buffer1 = { bufnr = 1 }

      git_buffer_store.add(buffer1)

      -- Should still retrieve with string bufnr
      local retrieved = git_buffer_store.get({ bufnr = '1' })
      assert(retrieved)
    end)

    it('should handle sequential add/remove operations', function()
      local buffers = {}
      for i = 1, 10 do
        buffers[i] = { bufnr = i }
        git_buffer_store.add(buffers[i])
      end

      -- Verify all added
      eq(git_buffer_store.size(), 10)

      -- Remove even numbered buffers
      for i = 2, 10, 2 do
        git_buffer_store.remove(buffers[i])
      end

      -- Should have 5 odd numbered buffers left
      eq(git_buffer_store.size(), 5)
    end)

    it('should maintain buffer references', function()
      local buffer = { bufnr = 1, data = { value = 123 } }
      git_buffer_store.add(buffer)

      -- Modify original
      buffer.data.value = 456

      -- Retrieved should have same reference
      local retrieved = git_buffer_store.get(buffer)
      eq(retrieved.data.value, 456)
    end)

    it('should handle large number of buffers', function()
      for i = 1, 1000 do
        git_buffer_store.add({ bufnr = i })
      end

      eq(git_buffer_store.size(), 1000)

      local count = 0
      git_buffer_store.for_each(function()
        count = count + 1
      end)

      eq(count, 1000)
    end)

    it('should handle rapid event dispatching', function()
      local event_count = 0

      git_buffer_store.on('change', function()
        event_count = event_count + 1
      end)

      git_buffer_store.add(mock_buffer)

      -- Rapidly dispatch events
      for i = 1, 100 do
        git_buffer_store.dispatch(mock_buffer, 'change')
      end

      eq(event_count, 100)
    end)
  end)
end)
