return function(busted, create_instance)
  local describe = busted.describe
  local it = busted.it
  local assert = busted.assert

  describe('get_key', function()
    it('should return key as-is for string input', function()
      local keymap = require('vgit.core.keymap')
      assert.are.same('q', keymap.get_key('q'))
      assert.are.same('<esc>', keymap.get_key('<esc>'))
    end)

    it('should return key from table input', function()
      local keymap = require('vgit.core.keymap')
      assert.are.same('q', keymap.get_key({ key = 'q', desc = 'quit' }))
      assert.are.same('j', keymap.get_key({ key = 'j', desc = 'down' }))
    end)

    it('should return nil for other types', function()
      local keymap = require('vgit.core.keymap')
      assert.is_nil(keymap.get_key(123))
      assert.is_nil(keymap.get_key(function() end))
    end)
  end)
end
