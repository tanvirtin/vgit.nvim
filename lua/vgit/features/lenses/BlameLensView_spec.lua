local eq = assert.are.same
local BlameLensView = require('vgit.features.lenses.BlameLensView')

describe('BlameLensView:', function()
  require('tests.helpers.get_key_tests')({ describe = describe, it = it, assert = assert }, function()
    return BlameLensView()
  end)

  describe('set_relative_lnum', function()
    local view
    local mock_diff_component

    before_each(function()
      view = BlameLensView()
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
      view._diff_component = mock_diff_component
    end)

    it('should return early if diff_component is nil', function()
      view._diff_component = nil
      view:set_relative_lnum(5, {})
      assert.is_nil(view:set_relative_lnum(5, {}))
    end)

    it('should return early if diff is nil', function()
      local result = view:set_relative_lnum(5, nil)
      assert.is_nil(result)
    end)

    it('should not error when no lnum_changes', function()
      local diff = {}
      view:set_relative_lnum(5, diff)
    end)

    it('should handle void type changes before current line', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'void', buftype = 'current' },
        },
      }
      view:set_relative_lnum(5, diff)
    end)

    it('should handle remove type changes before current line', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'remove', buftype = 'current' },
        },
      }
      view:set_relative_lnum(5, diff)
    end)

    it('should handle add type changes', function()
      local diff = {
        lnum_changes = {
          { lnum = 3, type = 'add', buftype = 'current' },
        },
      }
      view:set_relative_lnum(5, diff)
    end)

    it('should call move_to_hunk when get_relative_mark_index returns a value', function()
      mock_diff_component.get_relative_mark_index_return = 2
      local diff = { lnum_changes = {} }
      view:set_relative_lnum(5, diff)
      eq(2, mock_diff_component.move_to_hunk_called_with.hunk)
      eq('top', mock_diff_component.move_to_hunk_called_with.pos)
    end)

    it('should not call move_to_hunk when get_relative_mark_index returns nil', function()
      mock_diff_component.get_relative_mark_index_return = nil
      local diff = { lnum_changes = {} }
      view:set_relative_lnum(5, diff)
      eq(nil, mock_diff_component.move_to_hunk_called_with)
    end)
  end)

  describe('hunk_up', function()
    it('should call diff_component:hunk_up with top', function()
      local view = BlameLensView()
      local hunk_up_args = nil
      view._diff_component = {
        hunk_up = function(_, pos)
          hunk_up_args = pos
        end,
      }

      view:hunk_up()

      eq('top', hunk_up_args)
    end)
  end)

  describe('hunk_down', function()
    it('should call diff_component:hunk_down with top', function()
      local view = BlameLensView()
      local hunk_down_args = nil
      view._diff_component = {
        hunk_down = function(_, pos)
          hunk_down_args = pos
        end,
      }

      view:hunk_down()

      eq('top', hunk_down_args)
    end)
  end)

  describe('constructor', function()
    it('should initialize all fields correctly', function()
      local view = BlameLensView()
      assert.is_nil(view._blame)
      assert.is_nil(view._buffer)
      assert.is_nil(view._blame_info_component)
      assert.is_nil(view._diff_component)
      assert.is_false(view._destroyed)
    end)
  end)

  describe('destroy', function()
    it('should set destroyed flag', function()
      local view = BlameLensView()
      view:destroy()
      assert.is_true(view._destroyed)
    end)

    it('should be idempotent', function()
      local view = BlameLensView()
      view:destroy()
      assert.has_no.errors(function()
        view:destroy()
      end)
    end)
  end)
end)
