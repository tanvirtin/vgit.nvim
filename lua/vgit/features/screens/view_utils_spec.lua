local view_utils = require('vgit.features.screens.view_utils')

local eq = assert.are.same

describe('view_utils:', function()
  describe('get_key', function()
    it('should return string keymap as-is', function()
      eq('q', view_utils.get_key('q'))
    end)

    it('should return key from table keymap', function()
      eq('q', view_utils.get_key({ key = 'q' }))
    end)

    it('should return nil for non-string non-table input', function()
      assert.is_nil(view_utils.get_key(nil))
      assert.is_nil(view_utils.get_key(42))
    end)

    it('should handle table without key field', function()
      assert.is_nil(view_utils.get_key({ mode = 'n' }))
    end)
  end)

  describe('handle_git_error', function()
    it('should return true when no error', function()
      assert.is_true(view_utils.handle_git_error(nil, 'test_op', 'TestView'))
    end)

    it('should return false when error is present', function()
      assert.is_false(view_utils.handle_git_error('some error', 'test_op', 'TestView'))
    end)
  end)

  describe('get_hunk_alignment', function()
    it('should return a valid alignment value', function()
      local alignment = view_utils.get_hunk_alignment()
      local valid = { center = true, top = true, bottom = true }
      assert.is_true(valid[alignment] ~= nil)
    end)

    it('should use override when provided', function()
      local alignment = view_utils.get_hunk_alignment('bottom')
      eq('bottom', alignment)
    end)

    it('should fall back to default when override is invalid', function()
      local alignment = view_utils.get_hunk_alignment('invalid')
      eq('top', alignment)
    end)

    it('should fall back to global setting when override is nil', function()
      local alignment = view_utils.get_hunk_alignment(nil)
      local valid = { center = true, top = true, bottom = true }
      assert.is_true(valid[alignment] ~= nil)
    end)
  end)
end)
