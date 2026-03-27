local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  keymaps = {
    enter = { key = '<CR>', desc = 'Enter parent commit' },
    back = { key = '<BS>', desc = 'Go back to child commit' },
    diff = { key = 'd', desc = 'Show commit diff' },
    project_diff = { key = 'D', desc = 'Show commit project diff' },
    down = { key = '<C-j>', desc = 'Next blame segment' },
    up = { key = '<C-k>', desc = 'Previous blame segment' },
  },
})
