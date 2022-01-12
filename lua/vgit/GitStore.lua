local Object = require('vgit.core.Object')

local GitStore = Object:extend()

function GitStore:new()
  return setmetatable({ buffers = {} }, GitStore)
end

function GitStore:add(buffer)
  self.buffers[buffer.bufnr] = buffer
end

function GitStore:contains(buffer)
  return self.buffers[buffer.bufnr] ~= nil
end

function GitStore:remove(buffer, callback)
  if not buffer then
    return buffer
  end
  buffer = self.buffers[buffer.bufnr]
  if not buffer then
    return
  end
  self.buffers[buffer.bufnr] = nil
  if callback then
    callback(buffer)
  end
  return buffer
end

function GitStore:get(buffer)
  return self.buffers[buffer.bufnr]
end

function GitStore:current()
  local bufnr = vim.api.nvim_get_current_buf()
  return self.buffers[bufnr]
end

function GitStore:size()
  local count = 0
  for _, _ in pairs(self.buffers) do
    count = count + 1
  end
  return count
end

function GitStore:is_empty()
  return self:size() == 0
end

return GitStore
