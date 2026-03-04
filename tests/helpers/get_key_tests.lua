return function(busted, create_instance)
  local describe = busted.describe
  local it = busted.it
  local assert = busted.assert

  describe('get_key', function()
    it('should return key as-is for string input', function()
      local obj = create_instance()
      assert.are.same('q', obj:get_key('q'))
      assert.are.same('<esc>', obj:get_key('<esc>'))
    end)

    it('should return key from table input', function()
      local obj = create_instance()
      assert.are.same('q', obj:get_key({ key = 'q', desc = 'quit' }))
      assert.are.same('j', obj:get_key({ key = 'j', desc = 'down' }))
    end)

    it('should return nil for other types', function()
      local obj = create_instance()
      assert.is_nil(obj:get_key(123))
      assert.is_nil(obj:get_key(function() end))
    end)
  end)
end
