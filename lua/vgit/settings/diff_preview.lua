local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    buffer_stage = {
      key = 'S',
      desc = 'Stage',
    },
    buffer_unstage = {
      key = 'U',
      desc = 'Unstage',
    },
    reset = {
      key = 'r',
      desc = 'Reset',
    },
    buffer_hunk_stage = {
      key = 's',
      desc = 'Stage hunk',
    },
    buffer_hunk_unstage = {
      key = 'u',
      desc = 'Unstage hunk',
    },
    toggle_view = 't',
  },
})
