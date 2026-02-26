local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'top',
  keymaps = {
    add = {
      key = 'n',
      desc = 'Stash current changes',
    },
    apply = {
      key = 'a',
      desc = 'Apply stash',
    },
    pop = {
      key = 'p',
      desc = 'Pop stash',
    },
    drop = {
      key = 'd',
      desc = 'Drop stash',
    },
    clear = {
      key = 'D',
      desc = 'Clear all stashes',
    },
  },
})
