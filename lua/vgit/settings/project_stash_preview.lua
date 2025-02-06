local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    add = {
      key = 'A',
      desc = 'Add stash',
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
      key = 'C',
      desc = 'Clear stash',
    },
  },
})
