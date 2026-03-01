local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'top',
  hunk_alignment_offset = 0,
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
