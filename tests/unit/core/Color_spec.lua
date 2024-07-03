local Color = require('vgit.core.Color')

describe('Color:', function()
  describe('constructor', function()
    it('should initialize Color object with spec', function()
      local spec = { name = 'Normal', attribute = 'fg' }
      local color = Color(spec)

      assert.is_equal(color.spec, spec)
      assert.is_nil(color.rgb)
      assert.is_nil(color.hex)
    end)

    it('should throw an error if spec is nil', function()
      assert.has_error(function() Color(nil) end, 'spec is required')
    end)

    it('should throw an error if spec.name is nil', function()
      assert.has_error(function() Color({ attribute = 'fg' }) end, 'spec.name is required')
    end)

    it('should throw an error if spec.attribute is nil', function()
      assert.has_error(function() Color({ name = 'Normal' }) end, 'spec.attribute is required')
    end)
  end)

  describe('to_hex', function()
    it('should return cached hex value if already computed', function()
      local spec = { name = 'Normal', attribute = 'fg' }
      local color = Color(spec)
      color.hex = '#ff0000'

      assert.is_equal(color:to_hex(), '#ff0000')
    end)

    it('should return hex value based on spec', function()
      local spec = { name = 'Normal', attribute = 'fg' }
      vim.api.nvim_set_hl(0, 'Normal', { foreground = 16711680 })
      local color = Color(spec)

      assert.is_equal(color:to_hex(), '#ff0000')
    end)
  end)

  describe('to_rgb', function()
    it('should return Rgb object based on hex value', function()
      local spec = { name = 'Normal', attribute = 'fg' }
      vim.api.nvim_set_hl(0, 'Normal', { foreground = 16711680 })
      local color = Color(spec)
      local rgb = color:to_rgb()

      assert.is_equal(rgb.hex, '#ff0000')
    end)
  end)

  describe('get', function()
    it('should return the RGB value as a hex string', function()
      local spec = { name = 'Normal', attribute = 'fg' }
      vim.api.nvim_set_hl(0, 'Normal', { foreground = 16711680 })
      local color = Color(spec)

      assert.is_equal(color:get(), '#ff0000')
    end)
  end)

  describe('lighten', function()
    it('should lighten the color by the given percentage', function()
      vim.api.nvim_set_hl(0, 'Normal', { foreground = 16711680 })
      local initial_color = Color({ name = 'Normal', attribute = 'fg' })
      local color = Color({ name = 'Normal', attribute = 'fg' })

      color:lighten(50)

      local initial_rgb = initial_color:to_rgb()
      local rgb = color:to_rgb()

      assert.is_true(rgb.r > initial_rgb.r)
      assert.is_true(rgb.g == 0)
      assert.is_true(rgb.b == 0)
    end)
  end)

  describe('darken', function()
    it('should darken the color by the given percentage', function()
      vim.api.nvim_set_hl(0, 'Normal', { foreground = 16711680 })
      local initial_color = Color({ name = 'Normal', attribute = 'fg' })
      local color = Color({ name = 'Normal', attribute = 'fg' })

      color:darken(50)

      local initial_rgb = initial_color:to_rgb()
      local rgb = color:to_rgb()

      assert.is_true(rgb.r < initial_rgb.r)
      assert.is_true(rgb.g > initial_rgb.g)
      assert.is_true(rgb.b > initial_rgb.b)
    end)
  end)
end)
