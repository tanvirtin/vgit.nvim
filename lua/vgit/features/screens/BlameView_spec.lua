local eq = assert.are.same
local BlameView = require('vgit.features.screens.BlameView')

describe('BlameView:', function()
  describe('get_key', function()
    local view

    before_each(function()
      view = BlameView()
    end)

    it('should return key as-is for string input', function()
      eq('q', view:get_key('q'))
      eq('<esc>', view:get_key('<esc>'))
    end)

    it('should return key from table input', function()
      eq('q', view:get_key({ key = 'q', desc = 'quit' }))
      eq('j', view:get_key({ key = 'j', desc = 'down' }))
    end)

    it('should return nil for other types', function()
      assert.is_nil(view:get_key(123))
      assert.is_nil(view:get_key(function() end))
    end)
  end)
end)
