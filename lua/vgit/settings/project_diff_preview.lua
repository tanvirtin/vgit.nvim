local Config = require('vgit.core.Config')

return Config:new({
  keymaps = {
    buffer_stage = 's',
    buffer_unstage = 'u',
    stage_all = 'a',
    unstage_all = 'd',
    reset_all = 'r',
  },
})
