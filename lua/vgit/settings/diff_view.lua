local Config = require('vgit.core.Config')

return Config({
  -- Alignment when jumping to a hunk: 'top', 'center', or 'bottom'
  hunk_alignment = 'center',
  keymaps = {
    stage = {
      key = 'S',
      desc = 'Stage file',
    },
    unstage = {
      key = 'U',
      desc = 'Unstage file',
    },
    reset = {
      key = 'r',
      desc = 'Reset file',
    },

    stage_hunk = {
      key = 's',
      desc = 'Stage hunk',
    },
    unstage_hunk = {
      key = 'u',
      desc = 'Unstage hunk',
    },

    stage_all = {
      key = '<leader>S',
      desc = 'Stage all',
    },
    unstage_all = {
      key = '<leader>U',
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
    toggle_focus = {
      key = '<Tab>',
      desc = 'Switch focus between file list and diff preview'
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
