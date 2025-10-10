local eq = assert.are.same
local dimensions = require('vgit.ui.dimensions')

describe('dimensions:', function()
  describe('global_width', function()
    it('should return vim columns', function()
      local width = dimensions.global_width()

      assert.is_number(width)
      assert.is_true(width > 0, 'width should be positive')
      assert.equals(width, vim.o.columns)
    end)
  end)

  describe('global_height', function()
    it('should return vim lines', function()
      local height = dimensions.global_height()

      assert.is_number(height)
      assert.is_true(height > 0, 'height should be positive')
      assert.equals(height, vim.o.lines)
    end)
  end)

  describe('vh', function()
    it('should format value as vh string', function()
      eq(dimensions.vh(50), '50vh')
      eq(dimensions.vh(100), '100vh')
      eq(dimensions.vh(0), '0vh')
    end)

    it('should handle decimal values', function()
      eq(dimensions.vh(33.33), '33.33vh')
      eq(dimensions.vh(66.66), '66.66vh')
    end)
  end)

  describe('vw', function()
    it('should format value as vw string', function()
      eq(dimensions.vw(50), '50vw')
      eq(dimensions.vw(100), '100vw')
      eq(dimensions.vw(0), '0vw')
    end)

    it('should handle decimal values', function()
      eq(dimensions.vw(25.5), '25.5vw')
      eq(dimensions.vw(75.75), '75.75vw')
    end)
  end)

  describe('get_value', function()
    it('should extract numeric value from dimension string', function()
      eq(dimensions.get_value('50vh'), 50)
      eq(dimensions.get_value('100vw'), 100)
      eq(dimensions.get_value('33.5vh'), 33.5)
    end)

    it('should handle zero values', function()
      eq(dimensions.get_value('0vh'), 0)
      eq(dimensions.get_value('0vw'), 0)
    end)

    it('should handle decimal values', function()
      eq(dimensions.get_value('66.66vh'), 66.66)
      eq(dimensions.get_value('12.34vw'), 12.34)
    end)
  end)

  describe('get_unit', function()
    it('should extract unit from dimension string', function()
      eq(dimensions.get_unit('50vh'), 'vh')
      eq(dimensions.get_unit('100vw'), 'vw')
    end)

    it('should work with any numeric value', function()
      eq(dimensions.get_unit('0vh'), 'vh')
      eq(dimensions.get_unit('999.99vw'), 'vw')
    end)
  end)

  describe('relative_size', function()
    it('should return child when parent is nil', function()
      eq(dimensions.relative_size(nil, '50vh'), '50vh')
      eq(dimensions.relative_size(nil, '100vw'), '100vw')
    end)

    it('should return parent when child is nil', function()
      eq(dimensions.relative_size('50vh', nil), '50vh')
      eq(dimensions.relative_size('100vw', nil), '100vw')
    end)

    it('should return child when child is a number', function()
      eq(dimensions.relative_size('50vh', 42), 42)
      eq(dimensions.relative_size('100vw', 100), 100)
    end)

    it('should return parent when parent is a number', function()
      eq(dimensions.relative_size(42, '50vh'), 42)
      eq(dimensions.relative_size(100, '100vw'), 100)
    end)

    it('should return child when parent value is zero', function()
      eq(dimensions.relative_size('0vh', '50vh'), '50vh')
      eq(dimensions.relative_size('0vw', '100vw'), '100vw')
    end)

    it('should return parent when child ratio is zero', function()
      eq(dimensions.relative_size('50vh', '0vh'), '50vh')
      eq(dimensions.relative_size('100vw', '0vw'), '100vw')
    end)

    it('should calculate percentage of parent', function()
      eq(dimensions.relative_size('100vh', '50vh'), '50vh')
      eq(dimensions.relative_size('200vw', '25vw'), '50vw')
    end)

    it('should handle add operation', function()
      eq(dimensions.relative_size('100vh', '20vh', 'add'), '40vh')
      eq(dimensions.relative_size('100vw', '30vw', 'add'), '60vw')
    end)

    it('should handle remove operation', function()
      eq(dimensions.relative_size('100vh', '80vh', 'remove'), '0vh')
      eq(dimensions.relative_size('100vw', '60vw', 'remove'), '0vw')
    end)

    it('should preserve parent unit in result', function()
      local result = dimensions.relative_size('100vh', '50vh')
      assert.is_truthy(result:match('vh$'), 'result should end with vh')

      result = dimensions.relative_size('100vw', '50vw')
      assert.is_truthy(result:match('vw$'), 'result should end with vw')
    end)
  end)

  describe('relative_win_plot', function()
    it('should handle nil parent and child', function()
      local result = dimensions.relative_win_plot(nil, nil)

      assert.is_table(result)
      assert.is_nil(result.relative)
      assert.is_nil(result.height)
      assert.is_nil(result.width)
      assert.is_nil(result.row)
      assert.is_nil(result.col)
    end)

    it('should use parent values when child is empty', function()
      local parent = {
        relative = 'editor',
        height = '100vh',
        width = '100vw',
        row = '0vh',
        col = '0vw',
      }
      local result = dimensions.relative_win_plot(parent, {})

      eq(result.relative, 'editor')
      eq(result.height, '100vh')
      eq(result.width, '100vw')
    end)

    it('should override parent with child values', function()
      local parent = {
        relative = 'editor',
        height = '100vh',
        width = '100vw',
        row = '0vh',
        col = '0vw',
      }
      local child = {
        relative = 'cursor',
        height = '50vh',
        width = '50vw',
      }
      local result = dimensions.relative_win_plot(parent, child)

      eq(result.relative, 'cursor')
      eq(result.height, '50vh')
      eq(result.width, '50vw')
    end)

    it('should add child row to parent row', function()
      local parent = {
        height = '100vh',
        width = '100vw',
        row = '10vh',
        col = '10vw',
      }
      local child = {
        height = '50vh',
        width = '50vw',
        row = '5vh',
        col = '5vw',
      }
      local result = dimensions.relative_win_plot(parent, child)

      eq(result.row, '5.5vh')
      eq(result.col, '5.5vw')
    end)

    it('should preserve child zindex', function()
      local child = { zindex = 999 }
      local result = dimensions.relative_win_plot({}, child)

      eq(result.zindex, 999)
    end)
  end)

  describe('convert', function()
    it('should convert vh to absolute pixels', function()
      local height = dimensions.global_height()
      local result = dimensions.convert('50vh')

      assert.is_number(result)
      assert.equals(result, math.ceil((50 / 100) * height))
    end)

    it('should convert vw to absolute pixels', function()
      local width = dimensions.global_width()
      local result = dimensions.convert('50vw')

      assert.is_number(result)
      assert.equals(result, math.ceil((50 / 100) * width))
    end)

    it('should handle 100% viewport dimensions', function()
      local height = dimensions.global_height()
      local width = dimensions.global_width()

      assert.equals(dimensions.convert('100vh'), math.ceil(height))
      assert.equals(dimensions.convert('100vw'), math.ceil(width))
    end)

    it('should handle fractional percentages', function()
      local height = dimensions.global_height()
      local result = dimensions.convert('33.33vh')

      assert.is_number(result)
      assert.equals(result, math.ceil((33.33 / 100) * height))
    end)

    it('should return number as-is', function()
      eq(dimensions.convert(42), 42)
      eq(dimensions.convert(100), 100)
    end)

    it('should error on invalid unit', function()
      assert.has_error(function()
        dimensions.convert('50px')
      end)

      assert.has_error(function()
        dimensions.convert('100em')
      end)
    end)

    it('should ceil results to avoid fractional pixels', function()
      local result = dimensions.convert('33.33vh')
      assert.equals(result, math.floor(result), 'result should be an integer')
    end)
  end)

  describe('integration', function()
    it('should handle complete workflow: create, parse, calculate, convert', function()
      local dim = dimensions.vh(50)
      eq(dim, '50vh')

      local value = dimensions.get_value(dim)
      local unit = dimensions.get_unit(dim)
      eq(value, 50)
      eq(unit, 'vh')

      local parent = dimensions.vh(100)
      local relative = dimensions.relative_size(parent, dim)
      eq(relative, '50vh')

      local pixels = dimensions.convert(relative)
      local expected = math.ceil((50 / 100) * dimensions.global_height())
      eq(pixels, expected)
    end)

    it('should handle nested relative sizing', function()
      local parent = '100vh'
      local child = dimensions.relative_size(parent, '50vh')
      eq(child, '50vh')

      local grandchild = dimensions.relative_size(child, '40vh')
      eq(grandchild, '20vh')
    end)
  end)
end)
