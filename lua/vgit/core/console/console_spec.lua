local console = require('vgit.core.console')

local eq = assert.are.same

describe('console:', function()
  describe('format', function()
    it('should add [VGit] prefix to string messages', function()
      local result = console.format('Hello world')
      eq(result, '[VGit] Hello world')
    end)

    it('should format single-item table as single line with prefix', function()
      local result = console.format({ 'Single line' })
      eq(result, '[VGit] Single line')
    end)

    it('should format multi-line table with prefix and indentation', function()
      local result = console.format({ 'First line', 'Second line', 'Third line' })
      local expected = '[VGit] First line\n       Second line\n       Third line'
      eq(result, expected)
    end)

    it('should handle two-item table correctly', function()
      local result = console.format({ 'Line 1', 'Line 2' })
      local expected = '[VGit] Line 1\n       Line 2'
      eq(result, expected)
    end)

    it('should handle empty string', function()
      local result = console.format('')
      eq(result, '[VGit] ')
    end)

    it('should handle nil input', function()
      local result = console.format(nil)
      eq(result, '[VGit] ')
    end)

    it('should handle non-string non-table input', function()
      local result = console.format(42)
      eq(result, '[VGit] ')
    end)

    it('should not include a timestamp', function()
      local result = console.format('msg')
      assert.is_nil(result:match('%[%d%d:%d%d:%d%d%]'))
    end)

    it('should not include a log type bracket', function()
      local result = console.format('msg')
      -- only one bracket pair: [VGit]
      local count = 0
      for _ in result:gmatch('%[') do
        count = count + 1
      end
      eq(count, 1)
    end)
  end)

  describe('input', function()
    it('should call vim.fn.input and clear console', function()
      local original_input = vim.fn.input
      local input_called = false

      vim.fn.input = function(prompt)
        input_called = true
        return 'user_input'
      end

      local result = console.input('Test: ')

      vim.fn.input = original_input

      assert.is_true(input_called)
      eq(result, 'user_input')
    end)

    it('should return nil when vim.fn.input throws', function()
      local original_input = vim.fn.input

      vim.fn.input = function(prompt)
        error('Keyboard interrupt')
      end

      local result = console.input('Test: ')

      vim.fn.input = original_input

      assert.is_nil(result)
    end)
  end)

  describe('debug', function()
    after_each(function()
      console.debug.disable()
    end)

    describe('enable / disable', function()
      it('should enable debug logging', function()
        console.debug.disable()
        console.debug.enable()
        assert.is_true(console.debug.is_enabled())
      end)

      it('should disable debug logging', function()
        console.debug.enable()
        console.debug.disable()
        assert.is_false(console.debug.is_enabled())
      end)
    end)
  end)
end)
