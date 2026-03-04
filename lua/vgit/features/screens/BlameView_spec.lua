local eq = assert.are.same
local BlameView = require('vgit.features.screens.BlameView')
local save_package, restore_packages = require('tests.helpers.package_mock').create()

describe('BlameView:', function()
  require('tests.helpers.get_key_tests')({ describe = describe, it = it, assert = assert }, function()
    return BlameView()
  end)

  describe('_get_author_hl', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should return same color for same author', function()
      local hl1 = view:_get_author_hl('Alice')
      local hl2 = view:_get_author_hl('Alice')
      eq(hl1, hl2)
    end)

    it('should return a value from AUTHOR_COLORS', function()
      local hl = view:_get_author_hl('Bob')
      local found = false
      for _, color in ipairs(BlameView.AUTHOR_COLORS) do
        if color == hl then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it('should handle empty string', function()
      local hl = view:_get_author_hl('')
      assert.is_string(hl)
    end)

    it('should produce different colors for authors with different char sums', function()
      local results = {}
      for _, name in ipairs({ 'A', 'B', 'C', 'D', 'E', 'F', 'G' }) do
        results[view:_get_author_hl(name)] = true
      end
      local count = 0
      for _ in pairs(results) do count = count + 1 end
      assert.is_true(count >= 2)
    end)
  end)

  describe('_compute_blame_segments', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should group consecutive blames by hash', function()
      local blames = {
        { commit_hash = 'aaa' },
        { commit_hash = 'aaa' },
        { commit_hash = 'bbb' },
        { commit_hash = 'bbb' },
        { commit_hash = 'bbb' },
      }
      local segments = view:_compute_blame_segments(blames)
      eq(2, #segments)
      eq({ start = 1, finish = 2 }, segments[1])
      eq({ start = 3, finish = 5 }, segments[2])
    end)

    it('should handle single blame', function()
      local blames = { { commit_hash = 'aaa' } }
      local segments = view:_compute_blame_segments(blames)
      eq(1, #segments)
      eq({ start = 1, finish = 1 }, segments[1])
    end)

    it('should create one segment per hash when all different', function()
      local blames = {
        { commit_hash = 'aaa' },
        { commit_hash = 'bbb' },
        { commit_hash = 'ccc' },
      }
      local segments = view:_compute_blame_segments(blames)
      eq(3, #segments)
      eq({ start = 1, finish = 1 }, segments[1])
      eq({ start = 2, finish = 2 }, segments[2])
      eq({ start = 3, finish = 3 }, segments[3])
    end)

    it('should return empty for empty blames', function()
      local segments = view:_compute_blame_segments({})
      eq(0, #segments)
    end)

    it('should use hash field as fallback when commit_hash is nil', function()
      local blames = {
        { hash = 'aaa' },
        { hash = 'aaa' },
        { hash = 'bbb' },
      }
      local segments = view:_compute_blame_segments(blames)
      eq(2, #segments)
      eq({ start = 1, finish = 2 }, segments[1])
      eq({ start = 3, finish = 3 }, segments[2])
    end)

    it('should handle alternating hashes', function()
      local blames = {
        { commit_hash = 'aaa' },
        { commit_hash = 'bbb' },
        { commit_hash = 'aaa' },
      }
      local segments = view:_compute_blame_segments(blames)
      eq(3, #segments)
    end)
  end)

  describe('create validation', function()
    local view

    before_each(function()
      view = BlameView()
      save_package('vgit.core.console')
      package.loaded['vgit.core.console'] = {
        error = function() end,
        info = function() end,
      }
    end)

    after_each(function()
      restore_packages()
    end)

    it('should return false if no data provided', function()
      eq(false, view:create(nil))
    end)

    it('should return false if blames is nil', function()
      eq(false, view:create({ lines = { 'line1' }, filename = 'test.lua' }))
    end)

    it('should return false if blames is empty', function()
      eq(false, view:create({ blames = {}, lines = { 'line1' }, filename = 'test.lua' }))
    end)

    it('should return false if lines is nil', function()
      eq(false, view:create({ blames = { {} }, filename = 'test.lua' }))
    end)

    it('should return false if filename is nil', function()
      eq(false, view:create({ blames = { {} }, lines = { 'line1' } }))
    end)
  end)

  describe('blame_down', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should return early if no blame segments', function()
      view._blame_segments = {}
      view:blame_down()
    end)

    it('should navigate to next segment start', function()
      view._blame_segments = {
        { start = 1, finish = 3 },
        { start = 4, finish = 6 },
        { start = 7, finish = 10 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 1 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_down()
      eq(4, set_lnum_value)
    end)

    it('should jump from middle of segment to next segment start', function()
      view._blame_segments = {
        { start = 1, finish = 5 },
        { start = 6, finish = 10 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 3 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_down()
      eq(6, set_lnum_value)
    end)

    it('should not move past last segment', function()
      view._blame_segments = {
        { start = 1, finish = 3 },
        { start = 4, finish = 6 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 5 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_down()
      assert.is_nil(set_lnum_value)
    end)

    it('should jump to segment start when cursor is before it', function()
      view._blame_segments = {
        { start = 5, finish = 10 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 2 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_down()
      eq(5, set_lnum_value)
    end)
  end)

  describe('blame_up', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should return early if no blame segments', function()
      view._blame_segments = {}
      view:blame_up()
    end)

    it('should navigate to start of current segment when inside it', function()
      view._blame_segments = {
        { start = 1, finish = 3 },
        { start = 4, finish = 8 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 6 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_up()
      eq(4, set_lnum_value)
    end)

    it('should navigate to previous segment start when at segment start', function()
      view._blame_segments = {
        { start = 1, finish = 3 },
        { start = 4, finish = 6 },
        { start = 7, finish = 10 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 7 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_up()
      eq(4, set_lnum_value)
    end)

    it('should not move before first segment', function()
      view._blame_segments = {
        { start = 1, finish = 3 },
        { start = 4, finish = 6 },
      }

      local set_lnum_value = nil
      view._content_component = {
        with_element = function(_, fn)
          return fn({
            get_lnum = function() return 1 end,
            set_lnum = function(_, lnum) set_lnum_value = lnum end,
          })
        end,
      }

      view:blame_up()
      assert.is_nil(set_lnum_value)
    end)
  end)

  describe('destroy', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should set destroyed flag', function()
      view:destroy()
      assert.is_true(view:is_destroyed())
    end)

    it('should be idempotent', function()
      view:destroy()
      view:destroy()
      assert.is_true(view:is_destroyed())
    end)

    it('should call all debounce cleanup functions', function()
      local called = 0
      view._debounce_cleanups = {
        function() called = called + 1 end,
        function() called = called + 1 end,
      }

      view:destroy()
      eq(2, called)
    end)

    it('should clear debounce_cleanups list', function()
      view._debounce_cleanups = { function() end }
      view:destroy()
      eq(0, #view._debounce_cleanups)
    end)

    it('should destroy component manager if present', function()
      local destroyed = false
      view._component_manager = {
        destroy = function() destroyed = true end,
      }
      view:destroy()
      assert.is_true(destroyed)
    end)

    it('should not destroy component manager if nil', function()
      view._component_manager = nil
      view:destroy()
      assert.is_true(view:is_destroyed())
    end)
  end)
end)
