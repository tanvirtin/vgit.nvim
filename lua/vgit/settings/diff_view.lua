local Config = require('vgit.core.Config')

return Config({
  -- Alignment when jumping to a hunk: 'top', 'center', or 'bottom'
  hunk_alignment = 'center',
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

    hunk_up = {
      key = '[c',
      desc = 'Previous hunk',
    },
    hunk_down = {
      key = ']c',
      desc = 'Next hunk',
    },

    toggle_view = {
      key = 't',
      desc = 'Toggle between staged/unstaged',
    },
    next = {
      key = 'J',
      desc = 'Next'
    },
    previous = {
      key = 'K',
      desc = 'Previous'
    },
  },
})
