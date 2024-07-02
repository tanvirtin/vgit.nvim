local Rgb = require('vgit.core.Rgb')

describe('Rgb:', function()
  describe('constructor', function()
    it('should initialize Rgb object with hex and RGB values', function()
      local hex = '#ff0000'
      local rgb = Rgb(hex)

      assert.is_equal(rgb.hex, hex)
      assert.is_equal(rgb.r, 255)
      assert.is_equal(rgb.g, 0)
      assert.is_equal(rgb.b, 0)
    end)

    it('should handle nil hex input gracefully', function()
      local rgb = Rgb(nil)

      assert.is_nil(rgb.hex)
      assert.is_nil(rgb.r)
      assert.is_nil(rgb.g)
      assert.is_nil(rgb.b)
    end)
  end)

  describe('scale_up', function()
    it('should scale up RGB values by a percentage', function()
      local rgb = Rgb('#800000')
      rgb:scale_up(50)

      assert.is_equal(rgb.r, 192)
      assert.is_equal(rgb.g, 0)
      assert.is_equal(rgb.b, 0)
    end)

    it('should handle nil hex input gracefully', function()
      local rgb = Rgb(nil)
      rgb:scale_up(50)

      assert.is_nil(rgb.r)
      assert.is_nil(rgb.g)
      assert.is_nil(rgb.b)
    end)
  end)

  describe('scale_down()', function()
    it('should scale down RGB values by a percentage', function()
      local rgb = Rgb('#ff0000')
      rgb:scale_down(50)

      assert.is_equal(rgb.r, 127)
      assert.is_equal(rgb.g, 1)
      assert.is_equal(rgb.b, 1)
    end)

    it('should handle nil hex input gracefully', function()
      local rgb = Rgb(nil)
      rgb:scale_down(50)

      assert.is_nil(rgb.r)
      assert.is_nil(rgb.g)
      assert.is_nil(rgb.b)
    end)
  end)

  describe('get()', function()
    it('should return the hex representation of the RGB color', function()
      local rgb = Rgb('#ff0000')
      assert.is_equal(rgb:get(), '#ff0000')
    end)

    it('should return "NONE" if hex is nil', function()
      local rgb = Rgb(nil)
      assert.is_equal(rgb:get(), 'NONE')
    end)

    it('should cap RGB values at 255', function()
      local rgb = Rgb('#ff0000')
      rgb.r = 300
      rgb.g = 300
      rgb.b = 300

      assert.is_equal(rgb:get(), '#ffffff')
    end)
  end)
end)
