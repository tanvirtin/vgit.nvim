local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    reset = 'r',
    buffer_stage = 'S',
    buffer_unstage = 'U',
    buffer_hunk_stage = 's',
    buffer_hunk_unstage = 'u',
    toggle_view = 't',
  },
})
