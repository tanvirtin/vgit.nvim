local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    jump = {
      key = '<cr>',
      desc = 'Jump to file',
    },
    toggle_diff_preference = {
      key = 'x',
      desc = 'Toggle split/unified view',
    },
  },
})
