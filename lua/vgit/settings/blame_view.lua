local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  keymaps = {
    down = { key = '<C-j>', desc = 'Next blame segment' },
    up = { key = '<C-k>', desc = 'Previous blame segment' },
  },
})
