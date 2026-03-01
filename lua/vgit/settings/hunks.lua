local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'center',
  hunk_alignment_offset = 3,
  keymaps = {
    down = { key = '<C-j>', desc = 'Next hunk' },
    up = { key = '<C-k>', desc = 'Previous hunk' },
  },
})
