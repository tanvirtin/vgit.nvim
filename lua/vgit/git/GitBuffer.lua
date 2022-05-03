local loop = require('vgit.core.loop')
local Object = require('vgit.core.Object')
local git_buffer_store = require('vgit.git.git_buffer_store')

local GitBuffer = Object:extend()

function GitBuffer:constructor(buffer)
  return {
    buffer = buffer,
  }
end

function GitBuffer:is_in_store()
  loop.await_fast_event()
  if not git_buffer_store.contains(self.buffer) then
    return false
  end

  return true
end

function GitBuffer:is_inside_git_dir()
  loop.await_fast_event()
  local is_inside_git_dir = self.buffer.git_object:is_inside_git_dir()
  loop.await_fast_event()

  if not is_inside_git_dir then
    return false
  end

  return true
end

function GitBuffer:is_ignored()
  loop.await_fast_event()
  local is_ignored = self.buffer.git_object:is_ignored()
  loop.await_fast_event()

  if is_ignored then
    return true
  end

  return false
end

function GitBuffer:is_tracked()
  loop.await_fast_event()
  local tracked_filename = self.buffer.git_object:tracked_filename()
  loop.await_fast_event()

  if tracked_filename == '' then
    return false
  end

  return true
end

return GitBuffer
