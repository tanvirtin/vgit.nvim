local lazy = require('vgit.core.lazy')
local Config = lazy('vgit.core.Config')

return Config({
  hunk_alignment = 'top',
  keymaps = {
    stage = {
      key = 's',
      desc = 'Stage file',
    },
    unstage = {
      key = 'u',
      desc = 'Unstage file',
    },
    reset = {
      key = 'r',
      desc = 'Reset file',
    },

    stage_hunk = {
      key = '<leader>s',
      desc = 'Stage hunk',
    },
    unstage_hunk = {
      key = '<leader>u',
      desc = 'Unstage hunk',
    },
    reset_hunk = {
      key = '<leader>r',
      desc = 'Reset hunk',
    },

    stage_all = {
      key = 'S',
      desc = 'Stage all',
    },
    unstage_all = {
      key = 'U',
      desc = 'Unstage all',
    },
    reset_all = {
      key = '<leader>R',
      desc = 'Reset all',
    },
    commit = {
      key = 'C',
      desc = 'Commit',
    },
    commit_confirm = {
      key = '<C-s>',
      desc = 'Confirm commit',
    },
    commit_cancel = {
      key = 'q',
      desc = 'Cancel commit',
    },

    toggle_view = {
      key = 't',
      desc = 'Toggle between staged/unstaged',
    },
  },
})
