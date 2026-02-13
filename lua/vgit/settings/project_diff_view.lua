local lazy = require('vgit.core.lazy')
local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'center',
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
