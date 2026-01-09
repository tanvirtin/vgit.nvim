local Config = require('vgit.core.Config')

return Config({
  -- Alignment when jumping to a hunk: 'top', 'center', or 'bottom'
  hunk_alignment = 'center',
  keymaps = {
    commit = {
      key = 'C',
      desc = 'Commit',
    },
    buffer_stage = {
      key = 's',
      desc = 'Stage'
    },
    buffer_unstage = {
      key = 'u',
      desc = 'Unstage'
    },
    buffer_reset = {
      key = 'r',
      desc = 'Reset'
    },
    buffer_hunk_stage = {
      key = 'gs',
      desc = 'Stage hunk'
    },
    buffer_hunk_unstage = {
      key = 'gu',
      desc = 'Unstage hunk'
    },
    buffer_hunk_reset = {
      key = 'gr',
      desc = 'Reset hunk'
    },
    stage_all = {
      key = 'S',
      desc = 'Stage all'
    },
    unstage_all = {
      key = 'U',
      desc = 'Unstage all'
    },
    reset_all = {
      key = 'R',
      desc = 'Reset all'
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
