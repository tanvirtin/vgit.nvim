describe('icons', function()
  local icons

  before_each(function()
    icons = require('vgit.core.icons')
  end)

  describe('get', function()
    it('should return icon and color when nvim-web-devicons is loaded', function()
      package.loaded['nvim-web-devicons'] = {
        has_loaded = function()
          return true
        end,
        get_icon = function(fname, ext)
          return '', 'blue'
        end,
      }
      local icon, color = icons.get('icons_spec.lua', 'lua')
      assert.equals('', icon)
      assert.equals('blue', color)
    end)

    it('should return nil and empty string when nvim-web-devicons is not loaded', function()
      package.loaded['nvim-web-devicons'] = {
        has_loaded = function()
          return false
        end,
      }

      local icon, color = icons.get('test.txt', 'txt')
      assert.is_nil(icon)
      assert.equals('', color)
    end)
  end)
end)
