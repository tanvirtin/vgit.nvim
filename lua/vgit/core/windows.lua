local lazy = require('vgit.core.lazy')

local Window = lazy('vgit.core.Window')

local windows = {}

function windows.list()
  local win_ids = vim.api.nvim_list_wins()
  local result = {}
  for _, win_id in ipairs(win_ids) do
    result[#result + 1] = Window(win_id)
  end
  return result
end

return windows
