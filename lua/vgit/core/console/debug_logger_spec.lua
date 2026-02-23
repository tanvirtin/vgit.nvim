local env = require('vgit.core.env')
local fs = require('vgit.core.fs')

local eq = assert.are.same

describe('debug_logger:', function()
  local LOG_PATH = string.format('/tmp/vgit_%d.log', vim.fn.getpid())
  local debug_logger

  before_each(function()
    debug_logger = require('vgit.core.console.debug_logger')
    debug_logger.disable()
    env._reset()
    fs.remove_file(LOG_PATH)
  end)

  after_each(function()
    debug_logger.disable()
    fs.remove_file(LOG_PATH)
  end)

  describe('enable', function()
    it('should make is_enabled return true', function()
      debug_logger.enable()
      assert.is_true(debug_logger.is_enabled())
    end)

    it('should be idempotent', function()
      debug_logger.enable()
      debug_logger.enable()
      assert.is_true(debug_logger.is_enabled())
    end)
  end)

  describe('disable', function()
    it('should make is_enabled return false', function()
      debug_logger.enable()
      debug_logger.disable()
      assert.is_false(debug_logger.is_enabled())
    end)

    it('should be idempotent', function()
      debug_logger.disable()
      debug_logger.disable()
      assert.is_false(debug_logger.is_enabled())
    end)
  end)

  describe('is_enabled', function()
    it('should return false when VGIT_DEBUG is not set', function()
      eq(debug_logger.is_enabled(), false)
    end)

    it('should return true when VGIT_DEBUG is set to true', function()
      env.set('VGIT_DEBUG', true)
      eq(debug_logger.is_enabled(), true)
    end)

    it('should return false when VGIT_DEBUG is set to false', function()
      env.set('VGIT_DEBUG', false)
      eq(debug_logger.is_enabled(), false)
    end)

    it('should return false when VGIT_DEBUG is set to non-boolean string', function()
      env.set('VGIT_DEBUG', 'anything')
      eq(debug_logger.is_enabled(), false)
    end)

    it('should return false when VGIT_DEBUG is set to number', function()
      env.set('VGIT_DEBUG', 1)
      eq(debug_logger.is_enabled(), false)
    end)
  end)

  describe('append', function()
    it('should not write to file when debug is disabled', function()
      debug_logger.append('test message', 'info')
      eq(fs.exists(LOG_PATH), false)
    end)

    it('should write to file when debug is enabled', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('test message', 'info')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(#data > 0)
    end)

    it('should format message with log type', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('test message', 'info')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[VGit%]') ~= nil)
      assert.is_true(data[1]:match('%[INFO%]') ~= nil)
    end)

    it('should include source and function name when provided', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('test message', 'info', '@test.lua', 'test_func')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[@test%.lua%]') ~= nil)
      assert.is_true(data[1]:match('%[test_func%]') ~= nil)
    end)

    it('should append multiple messages to same file', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('first message', 'info')
      debug_logger.append('second message', 'error')

      local data = fs.read_file(LOG_PATH)
      eq(#data, 2)
      assert.is_true(data[1]:match('first message') ~= nil)
      assert.is_true(data[2]:match('second message') ~= nil)
    end)

    it('should handle empty message', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('', 'info')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(#data > 0)
    end)

    it('should handle nil fn_name', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.append('test message', 'info', '@test.lua', nil)

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[@test%.lua%]') ~= nil)
      assert.is_true(data[1]:match('test message') ~= nil)
    end)
  end)

  describe('info', function()
    it('should log with info level when enabled', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.info('info message')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[INFO%]') ~= nil)
      assert.is_true(data[1]:match('info message') ~= nil)
    end)

    it('should not write when debug is disabled', function()
      debug_logger.info('should not appear')
      eq(fs.exists(LOG_PATH), false)
    end)
  end)

  describe('error', function()
    it('should log with error level when enabled', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.error('error message')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[ERROR%]') ~= nil)
      assert.is_true(data[1]:match('error message') ~= nil)
    end)

    it('should not write when debug is disabled', function()
      debug_logger.error('should not appear')
      eq(fs.exists(LOG_PATH), false)
    end)
  end)

  describe('warning', function()
    it('should log with warn level when enabled', function()
      env.set('VGIT_DEBUG', true)
      debug_logger.warning('warning message')

      local data = fs.read_file(LOG_PATH)
      assert.is_true(data[1]:match('%[WARN%]') ~= nil)
      assert.is_true(data[1]:match('warning message') ~= nil)
    end)

    it('should not write when debug is disabled', function()
      debug_logger.warning('should not appear')
      eq(fs.exists(LOG_PATH), false)
    end)
  end)

  describe('get_path', function()
    it('should return the log file path', function()
      eq(debug_logger.get_path(), LOG_PATH)
    end)
  end)

  describe('open', function()
    it('should show warning when debug is disabled', function()
      local notified = false
      local original_notify = vim.notify
      vim.notify = function(msg, level)
        if msg:match('Debug mode is not enabled') then notified = true end
      end

      debug_logger.open()

      vim.notify = original_notify
      assert.is_true(notified)
    end)
  end)
end)
