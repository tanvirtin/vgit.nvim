local lazy = require('vgit.core.lazy')
local Config = lazy('vgit.core.Config')

return Config({
  keymaps = {
    stage = { key = 's', desc = 'Stage file' },
    unstage = { key = 'u', desc = 'Unstage file' },
    reset = { key = 'r', desc = 'Reset file' },
    stage_hunk = { key = '<leader>s', desc = 'Stage hunk' },
    unstage_hunk = { key = '<leader>u', desc = 'Unstage hunk' },
    toggle_view = { key = 't', desc = 'Toggle staged/unstaged' },
  },
})
