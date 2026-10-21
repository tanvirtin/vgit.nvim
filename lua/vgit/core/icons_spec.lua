local eq = assert.are.same

describe('icons:', function()
  local icons

  before_each(function()
    package.loaded['vgit.core.icons'] = nil
    icons = require('vgit.core.icons')
  end)

  after_each(function()
    package.loaded['nvim-web-devicons'] = nil
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

    it('should stop looking for nvim-web-devicons after it fails to load', function()
      package.loaded['nvim-web-devicons'] = nil
      local attempts = 0
      table.insert(package.loaders, 1, function(name)
        if name == 'nvim-web-devicons' then attempts = attempts + 1 end
        return '\n\tno nvim-web-devicons in this test'
      end)

      assert.is_false(pcall(require, 'nvim-web-devicons'))
      attempts = 0

      local first_icon = icons.get('a.lua', 'lua')
      local second_icon = icons.get('b.lua', 'lua')
      table.remove(package.loaders, 1)

      assert.is_nil(first_icon)
      assert.is_nil(second_icon)
      eq(1, attempts)
    end)
  end)
end)
