local loop = require('vgit.core.loop')
local event = require('vgit.core.event')
local Buffer = require('vgit.core.Buffer')
local Object = require('vgit.core.Object')
local event_type = require('vgit.core.event_type')
local GitBlob = require('vgit.services.git.GitBlob')
local GitRepository = require('vgit.services.git.GitRepository')

local Git = Object:extend()

Git.store = {
  buffers = {},
}

function Git:get_blob(filename, status, log) return GitBlob(filename, status, log) end

function Git:get_repository(cwd) return GitRepository(cwd) end

function Git.store.handle_buf_detach(buffer)
  Git.store.remove(buffer, function() buffer:destroy() end)
  event.emit(event_type.VGitBufDetached, buffer:serialize())
end

function Git.store.handle_buf_add()
  loop.await()
  local buffer = Buffer(0)

  loop.await()
  if Git.store.contains(buffer) then
    return
  end

  loop.await()
  buffer:sync_git(Git)

  local _, is_inside_git_dir = buffer.git_blob:is_inside_git_dir()
  loop.await()

  if not is_inside_git_dir then
    return
  end

  loop.await()
  if not buffer:is_valid() then
    return
  end

  loop.await()
  if not buffer:is_in_disk() then
    return
  end

  loop.await()
  local _, is_ignored = buffer.git_blob:is_ignored()

  if is_ignored then
    return
  end

  loop.await()
  Git.store.add(buffer)
  loop.await()

  event.emit(event_type.VGitBufAttached, buffer:serialize())

  buffer:attach_to_changes({
    on_detach = loop.async(function() Git.store.handle_buf_detach(buffer) end),
  })
end

function Git.store.register_events()
  event.create(event_type.VGitBufAttached)
  event.create(event_type.VGitBufDetached)
  event.on(event_type.BufRead, Git.store.handle_buf_add)
end

function Git.store.add(buffer)
  Git.store.buffers[buffer.bufnr] = buffer

  return Git.store
end

function Git.store.contains(buffer) return Git.store.buffers[buffer.bufnr] ~= nil end

function Git.store.remove(buffer, callback)
  if not buffer then
    return buffer
  end

  buffer = Git.store.buffers[buffer.bufnr]

  if not buffer then
    return
  end

  Git.store.buffers[buffer.bufnr] = nil

  if callback then
    callback(buffer)
  end

  return buffer
end

function Git.store.get(buffer) return Git.store.buffers[buffer.bufnr] end

function Git.store.current()
  local bufnr = vim.api.nvim_get_current_buf()

  return Git.store.buffers[bufnr]
end

function Git.store.size()
  local count = 0

  for _, _ in pairs(Git.store.buffers) do
    count = count + 1
  end

  return count
end

function Git.store.is_empty() return Git.store.size() == 0 end

return Git
