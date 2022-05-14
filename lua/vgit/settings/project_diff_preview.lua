local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    buffer_stage = 's',
    buffer_unstage = 'u',
    buffer_hunk_stage = 'gs',
    buffer_hunk_unstage = 'gu',
    stage_all = 'S',
    unstage_all = 'U',
    reset_all = 'R',
  },
})
