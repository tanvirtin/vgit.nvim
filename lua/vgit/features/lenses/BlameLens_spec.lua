local eq = assert.are.same
local BlameLens = require('vgit.features.lenses.BlameLens')

describe('BlameLens:', function()
  describe('get_key', function()
    local lens

    before_each(function()
      lens = BlameLens()
    end)

    it('should return key as-is for string input', function()
      eq('q', lens:get_key('q'))
      eq('<esc>', lens:get_key('<esc>'))
    end)

    it('should return key from table input', function()
      eq('q', lens:get_key({ key = 'q', desc = 'quit' }))
      eq('j', lens:get_key({ key = 'j', desc = 'down' }))
    end)

    it('should return nil for other types', function()
      assert.is_nil(lens:get_key(123))
      assert.is_nil(lens:get_key(function() end))
    end)
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
end)
