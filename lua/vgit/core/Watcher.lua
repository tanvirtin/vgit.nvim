local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')

local luv = vim.loop

local Watcher = Object:extend()

function Watcher:constructor(interval)
  return {
    watcher = nil,
    interval = interval or 1000,
  }
end

function Watcher:watch_file(path, handler)
  if self.watcher then
    return self.watcher
  end

  self.watcher = vim.loop.new_fs_event()

  vim.loop.fs_event_start(self.watcher, path, {
    watch_entry = false,
    stat = false,
    recursive = false,
  }, handler)

  return self
end

function Watcher:watch_dir(path, handler)
  if self.watcher then
    return self.watcher
  end

  self.watcher = vim.loop.new_fs_poll()

  self.watcher:start(path, self.interval, loop.coroutine(handler))

  return self
end

function Watcher:unwatch()
  if not self.watcher then
    return
  end

  luv.fs_event_stop(self.watcher)
  self.watcher = nil

  return self
end

return Watcher
