local loop = require('vgit.core.loop')
local Git = require('vgit.git.cli.Git')
local event = require('vgit.core.event')
local utils = require('vgit.core.utils')
local Watcher = require('vgit.core.Watcher')
local GitBuffer = require('vgit.git.GitBuffer')
local event_type = require('vgit.core.event_type')

local buffers = {}
local event_handlers = {
  watch = {},
  attach = {},
  change = {},
  reload = {},
  detach = {},
  render = {},
  register = {},
  git_watch = {},
}
local dir_watcher = Watcher()
local is_registerd = false

local git_buffer_store = {}

git_buffer_store.register_events = loop.async(function()
  if is_registerd then
    return
  end

  is_registerd = true

  event.on(event_type.BufRead, function() git_buffer_store.collect() end)

  for _, handler in pairs(event_handlers.register) do
    loop.await()
    handler()
  end

  local git = Git()

  loop.await()
  if not git:is_inside_git_dir() then
    return
  end

  loop.await()
  local err, git_dir = git:get_git_dir()

  if err then
    return
  end

  dir_watcher:watch_dir(git_dir, function()
    local git_buffers = utils.object.values(buffers)

    for i = 1, #git_buffers do
      loop.await()
      git_buffers[i]:sync()
    end

    for _, handler in pairs(event_handlers.git_watch) do
      loop.await()
      handler(git_buffers)
    end
  end)
end)

git_buffer_store.for_each = function(callback)
  for _, git_buffer in pairs(buffers) do
    callback(git_buffer)
  end
end

git_buffer_store.attach = function(type, handler)
  local handlers = event_handlers[type]
  handlers[#handlers + 1] = handler

  return git_buffer_store
end

git_buffer_store.add = function(buffer)
  buffers[buffer.bufnr] = buffer

  return git_buffer_store
end

git_buffer_store.contains = function(buffer) return buffers[buffer.bufnr] ~= nil end

git_buffer_store.remove = function(buffer, callback)
  if not buffer then
    return buffer
  end

  buffer = buffers[buffer.bufnr]

  if not buffer then
    return
  end

  buffers[buffer.bufnr] = nil

  if callback then
    callback(buffer)
  end

  return buffer
end

git_buffer_store.get = function(buffer) return buffers[buffer.bufnr] end

function git_buffer_store.current()
  local bufnr = vim.api.nvim_get_current_buf()

  return buffers[bufnr]
end

git_buffer_store.size = function()
  local count = 0

  for _, _ in pairs(buffers) do
    count = count + 1
  end

  return count
end

git_buffer_store.is_empty = function() return git_buffer_store.size() == 0 end

git_buffer_store.collect = function()
  loop.await()
  local git_buffer = GitBuffer(0)

  loop.await()
  if git_buffer_store.contains(git_buffer) then
    return
  end

  loop.await()
  git_buffer:sync()

  loop.await()
  if not git_buffer:is_inside_git_dir() then
    return
  end

  loop.await()
  if not git_buffer:is_valid() then
    return
  end

  loop.await()
  if not git_buffer:is_in_disk() then
    return
  end

  loop.await()
  if git_buffer:is_ignored() then
    return
  end

  loop.await()
  git_buffer_store.add(git_buffer)
  loop.await()

  git_buffer
    :attach_to_changes({
      on_lines = loop.async(function(_, _, _, _, p_lnum, n_lnum, byte_count)
        if p_lnum == n_lnum and byte_count == 0 then
          return
        end

        for _, handler in pairs(event_handlers.change) do
          handler(git_buffer, p_lnum, n_lnum, byte_count)
        end
      end),

      on_reload = loop.async(function()
        for _, handler in pairs(event_handlers.reload) do
          handler(git_buffer)
        end
      end),

      on_detach = loop.async(function()
        for _, handler in pairs(event_handlers.detach) do
          loop.await()
          handler(git_buffer)
        end

        git_buffer:unwatch():detach_from_renderer()
        git_buffer_store.remove(git_buffer)
      end),
    })
    :attach_to_renderer(loop.async(function(top, bot)
      for _, handler in pairs(event_handlers.render) do
        handler(git_buffer, top, bot)
      end
    end))

  git_buffer:watch(loop.async(function()
    for _, handler in pairs(event_handlers.watch) do
      handler(git_buffer)
    end
  end))

  for _, handler in pairs(event_handlers.attach) do
    handler(git_buffer)
  end
end

return git_buffer_store
