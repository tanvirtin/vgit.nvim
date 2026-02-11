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
  end)

  describe('debug', function()
    describe('get_source_logger', function()
      it('should append to source array when DEBUG is enabled', function()
        local env = require('vgit.core.env')
        local original_get = env.get
        env.get = function(key)
          if key == 'DEBUG' then return true end
          return original_get(key)
        end

        local source = {}
        local logger = console.debug.get_source_logger(source)
        logger('test message')

        env.get = original_get

        assert.is_true(#source > 0)
        assert.is_true(source[1]:match('test message') ~= nil)
      end)

      it('should not append when DEBUG is disabled', function()
        local env = require('vgit.core.env')
        local original_get = env.get
        env.get = function(key)
          if key == 'DEBUG' then return false end
          return original_get(key)
        end

        local source = {}
        local logger = console.debug.get_source_logger(source)
        logger('test message')

        env.get = original_get

        eq(#source, 0)
      end)

      it('should format table messages with commas', function()
        local env = require('vgit.core.env')
        local original_get = env.get
        env.get = function(key)
          if key == 'DEBUG' then return true end
          return original_get(key)
        end

        local source = {}
        local logger = console.debug.get_source_logger(source)
        logger({ 'msg1', 'msg2', 'msg3' })

        env.get = original_get

        assert.is_true(#source > 0)
        assert.is_true(source[1]:match('msg1, msg2, msg3') ~= nil)
      end)

      it('should return console for chaining', function()
        local logger = console.debug.get_source_logger({})
        local result = logger('test')
        eq(result, console)
      end)
    end)
  end)
end)
