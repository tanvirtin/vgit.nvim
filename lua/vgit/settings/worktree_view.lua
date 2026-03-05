local lazy = require('vgit.core.lazy')

local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'top',
  hunk_alignment_offset = 3,
  keymaps = {
    add = {
      key = 'n',
      desc = 'Add new worktree',
    },
    remove = {
      key = 'd',
      desc = 'Remove worktree',
    },
    switch = {
      key = '<CR>',
      desc = 'Switch to worktree',
    },
  },
})
