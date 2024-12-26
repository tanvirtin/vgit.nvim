local Buffer = require('vgit.core.Buffer')

local buffer_store = {}

function buffer_store.list()
  local buffers = {}
  local bufnrs = vim.api.nvim_list_bufs()

  for i = 1, #bufnrs do
    buffers[#buffers + 1] = Buffer(bufnrs[i])
  end

  return buffers
end

return buffer_store
