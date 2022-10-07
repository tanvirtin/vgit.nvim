local Object = require('vgit.core.Object')
local GitBlob = require('vgit.services.git.GitBlob')
local GitRepository = require('vgit.services.git.GitRepository')

local Git = Object:extend()

Git.store = {
  buffers = {},
}

function Git:get_blob(filename, status, log) return GitBlob(filename, status, log) end

function Git:get_repository(cwd) return GitRepository(cwd) end

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
