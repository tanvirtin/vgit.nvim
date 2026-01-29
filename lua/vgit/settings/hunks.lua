local Config = require('vgit.core.Config')

return Config({
  hunk_alignment = 'center',
  keymaps = {
    down = { key = '<C-j>', desc = 'Next hunk' },
    up = { key = '<C-k>', desc = 'Previous hunk' },
  },
})
