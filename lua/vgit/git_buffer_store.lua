local buffers = {}

local git_buffer_store = {}

git_buffer_store.add = function(buffer)
  buffers[buffer.bufnr] = buffer
end

git_buffer_store.contains = function(buffer)
  return buffers[buffer.bufnr] ~= nil
end

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

git_buffer_store.get = function(buffer)
  return buffers[buffer.bufnr]
end

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

git_buffer_store.is_empty = function()
  return git_buffer_store.size() == 0
end

return git_buffer_store
