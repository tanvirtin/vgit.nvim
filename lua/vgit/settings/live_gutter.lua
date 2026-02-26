local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  enabled = true,
  debounce_ms = 200,
  edge_navigation = true,
})
