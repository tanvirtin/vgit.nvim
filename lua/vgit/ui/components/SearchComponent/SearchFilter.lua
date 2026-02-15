local lazy = require('vgit.core.lazy')
local Object = lazy('vgit.core.Object')

local SearchFilter = Object:extend()

function SearchFilter:constructor()
  return {}
end

function SearchFilter:filter(items, query)
  if not items then return {} end
  if not query or query == '' then return items end

  local lower_query = query:lower()
  local filtered = {}

  for i = 1, #items do
    local item = items[i]
    local label = item.label
    if label and label:lower():find(lower_query, 1, true) then
      filtered[#filtered + 1] = item
    end
  end

  return filtered
end

return SearchFilter
