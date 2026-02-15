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
  local lookup = {}

  for i = 1, #items do
    local item = items[i]
    lookup[#lookup + 1] = {
      _original = item,
      label = item.label and item.label:lower() or '',
    }
  end

  local matched = vim.fn.matchfuzzy(lookup, lower_query, { key = 'label' })
  local result = {}

  for i = 1, #matched do
    result[#result + 1] = matched[i]._original
  end

  return result
end

return SearchFilter
