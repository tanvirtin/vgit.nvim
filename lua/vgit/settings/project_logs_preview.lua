local Config = require('vgit.core.Config')

return Config({
  keymaps = {
    previous = {
      key = '-',
      desc = 'Previous',
    },
    next = {
      key = '=',
      desc = 'Next',
    },
  },
})
