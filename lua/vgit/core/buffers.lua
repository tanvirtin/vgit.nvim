local lazy = require('vgit.core.lazy')

local Buffer = lazy('vgit.core.Buffer')

local buffers = {}

function buffers.list()
  local bufnrs = vim.api.nvim_list_bufs()
  local result = {}
  for _, bufnr in ipairs(bufnrs) do
    result[#result + 1] = Buffer(bufnr)
  end
  return result
end

return buffers
