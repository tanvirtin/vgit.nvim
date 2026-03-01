local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'top',
  hunk_alignment_offset = 3,
})
