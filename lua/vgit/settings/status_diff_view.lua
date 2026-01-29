local Config = require('vgit.core.Config')

-- Note: hunk_alignment and keymaps.down/up are inherited from hunks setting
-- Users can override them here for this view only
return Config({
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

    toggle_view = {
      key = 't',
      desc = 'Toggle between staged/unstaged',
    },
  },
})
