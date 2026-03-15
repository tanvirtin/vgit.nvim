local eq = assert.are.same
local BlameLens = require('vgit.features.lenses.BlameLens')

describe('BlameLens:', function()
  require('tests.helpers.get_key_tests')({ describe = describe, it = it, assert = assert }, function()
    return BlameLens()
  end)

  describe('set_relative_lnum', function()
    local lens
    local mock_diff_component

    before_each(function()
      lens = BlameLens()
      mock_diff_component = {
        move_to_hunk_called_with = nil,
        set_lnum_called_with = nil,
        get_relative_mark_index_return = nil,
        move_to_hunk = function(self, hunk, pos)
          self.move_to_hunk_called_with = { hunk = hunk, pos = pos }
        end,
        set_lnum = function(self, lnum)
          self.set_lnum_called_with = lnum
        end,
        get_relative_mark_index = function(self, lnum)
          return self.get_relative_mark_index_return
        end,
      }
      lens.diff_component = mock_diff_component
    end)

    it('should return early if diff_component is nil', function()
      lens.diff_component = nil
      lens:set_relative_lnum(5, {})
      assert.is_nil(lens:set_relative_lnum(5, {}))
    end)

    it('should return early if diff is nil', function()
      local result = lens:set_relative_lnum(5, nil)
      assert.is_nil(result)
    end)

    it('should not error when no lnum_changes', function()
      local diff = {}
      lens:set_relative_lnum(5, diff)
    end)

    it('should handle void type changes before current line', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'void', buftype = 'current' },
        },
      }
      lens:set_relative_lnum(5, diff)
    end)

    it('should handle remove type changes before current line', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'remove', buftype = 'current' },
        },
      }
      lens:set_relative_lnum(5, diff)
    end)

    it('should handle add type changes', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'add', buftype = 'current' },
        },
      }
      lens:set_relative_lnum(5, diff)
    end)

    it('should call move_to_hunk when get_relative_mark_index returns a value', function()
      mock_diff_component.get_relative_mark_index_return = 2
      local diff = { lnum_changes = {} }
      lens:set_relative_lnum(5, diff)
      eq(2, mock_diff_component.move_to_hunk_called_with.hunk)
      eq('top', mock_diff_component.move_to_hunk_called_with.pos)
    end)

    it('should not call move_to_hunk when get_relative_mark_index returns nil', function()
      mock_diff_component.get_relative_mark_index_return = nil
      local diff = { lnum_changes = {} }
      lens:set_relative_lnum(5, diff)
      eq(nil, mock_diff_component.move_to_hunk_called_with)
    end)
  end)

  describe('prev_hunk', function()
    it('should call diff_component:hunk_up with top', function()
      local lens = BlameLens()
      local hunk_up_args = nil
      lens.diff_component = {
        hunk_up = function(_, pos)
          hunk_up_args = pos
        end,
      }

      lens:prev_hunk()

      eq('top', hunk_up_args)
    end)
  end)

  describe('next_hunk', function()
    it('should call diff_component:hunk_down with top', function()
      local lens = BlameLens()
      local hunk_down_args = nil
      lens.diff_component = {
        hunk_down = function(_, pos)
          hunk_down_args = pos
        end,
      }

      lens:next_hunk()

      eq('top', hunk_down_args)
    end)
  end)

  describe('emit_cleanup_events', function()
    it('should call component_will_unmount on blame_info_component', function()
      local lens = BlameLens()
      local unmount_called = false
      lens.blame_info_component = {
        component_will_unmount = function()
          unmount_called = true
        end,
      }
      lens.diff_component = nil

      lens:emit_cleanup_events()

      assert.is_true(unmount_called)
    end)

    it('should call component_will_unmount on diff_component when present', function()
      local lens = BlameLens()
      local blame_unmount = false
      local diff_unmount = false
      lens.blame_info_component = {
        component_will_unmount = function()
          blame_unmount = true
        end,
      }
      lens.diff_component = {
        component_will_unmount = function()
          diff_unmount = true
        end,
      }

      lens:emit_cleanup_events()

      assert.is_true(blame_unmount)
      assert.is_true(diff_unmount)
    end)

    it('should not error when diff_component is nil', function()
      local lens = BlameLens()
      lens.blame_info_component = {
        component_will_unmount = function() end,
      }
      lens.diff_component = nil

      -- Should not error
      lens:emit_cleanup_events()
    end)
  end)

  describe('destroy', function()
    it('should call emit_cleanup_events and component_manager:destroy', function()
      local lens = BlameLens()
      local cm_destroyed = false
      local blame_unmount = false
      lens.blame_info_component = {
        component_will_unmount = function()
          blame_unmount = true
        end,
      }
      lens.diff_component = nil
      lens.component_manager = {
        destroy = function()
          cm_destroyed = true
        end,
      }

      lens:destroy()

      assert.is_true(blame_unmount)
      assert.is_true(cm_destroyed)
    end)
  end)

  describe('constructor', function()
    it('should initialize all fields as nil', function()
      local lens = BlameLens()
      assert.is_nil(lens.blame)
      assert.is_nil(lens.buffer)
      assert.is_nil(lens.blame_info_component)
      assert.is_nil(lens.diff_component)
      assert.is_nil(lens.component_manager)
      assert.is_nil(lens.pending_quit_key)
    end)
  end)
end)
