local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    buffer_stage = 's',
    buffer_unstage = 'u',
    stage_all = 'S',
    unstage_all = 'U',
    reset_all = 'R',
    clean_all = 'C',
  },
})
