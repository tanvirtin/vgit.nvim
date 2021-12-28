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

function GitStore:remove(buffer)
  buffer = self.buffers[buffer.bufnr]
  self.buffers[buffer.bufnr] = nil
  return buffer
end

function GitStore:get(buffer)
  return self.buffers[buffer.bufnr]
end

function GitStore:clean(callback)
  local bufnrs = vim.api.nvim_list_bufs()
  local bufnr_map = {}
  for i = 1, #bufnrs do
    local bufnr = bufnrs[i]
    bufnr_map[bufnr] = true
  end
  local buffers = {}
  for bufnr, buffer in pairs(self.buffers) do
    if not bufnr_map[bufnr] then
      buffers[#buffers + 1] = buffer
      self.buffers[bufnr] = nil
      if callback then
        callback(buffer)
      end
    end
  end
  return buffers
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
