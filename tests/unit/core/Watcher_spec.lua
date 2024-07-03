local Watcher = require('vgit.core.Watcher')

describe('Watcher', function()
  local watcher
  local interval = 1000
  local path = string.format('%s/tests/mock/fixtures/file1', vim.loop.cwd())

  before_each(function()
    watcher = Watcher(interval)
  end)

  describe('constructor', function()
    it('should initialize a Watcher object with default properties', function()
      assert.is_nil(watcher.watcher)
      assert.equals(interval, watcher.interval)
    end)

    it('should initialize a Watcher object with the specified interval', function()
      local w = Watcher(2000)
      assert.is_nil(w.watcher)
      assert.equals(2000, w.interval)
    end)
  end)

  describe('watch_file', function()
    it('should start watching a file', function()
      watcher:watch_file(path, function()end)
      assert.is_not_nil(watcher.watcher)
    end)
  end)

  describe('watch_dir', function()
    it('should start watching a directory', function()
      watcher:watch_dir(path, function()end)
      assert.is_not_nil(watcher.watcher)
    end)
  end)

  describe('unwatch', function()
    it('should stop watching and reset the watcher', function()
      watcher:watch_file(path, function() end)
      watcher:unwatch()

      assert.is_nil(watcher.watcher)
    end)
  end)
end)
