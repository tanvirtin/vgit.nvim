local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    commit = 'C',
    buffer_stage = 's',
    buffer_unstage = 'u',
    buffer_hunk_stage = 'gs',
    buffer_hunk_unstage = 'gu',
    buffer_reset = 'r',
    stage_all = 'S',
    unstage_all = 'U',
    reset_all = 'R',
  },
})
