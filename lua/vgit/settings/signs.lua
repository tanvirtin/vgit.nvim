local Config = require('vgit.core.Config')

return Config({
  priority = 10,
  definitions = {
    GitConflictCurrentMark = {
      linehl = 'GitConflictCurrentMark',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictAncestorMark = {
      linehl = 'GitConflictAncestorMark',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictIncomingMark = {
      linehl = 'GitConflictIncomingMark',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictCurrent = {
      linehl = 'GitConflictCurrent',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictAncestor = {
      linehl = 'GitConflictAncestor',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictMiddle = {
      linehl = 'GitConflictMiddle',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitConflictIncoming = {
      linehl = 'GitConflictIncoming',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitSignsAddLn = {
      linehl = 'GitSignsAddLn',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitSignsDeleteLn = {
      linehl = 'GitSignsDeleteLn',
      texthl = nil,
      numhl = nil,
      icon = nil,
      text = '',
    },
    GitSignsAdd = {
      texthl = 'GitSignsAdd',
      numhl = nil,
      icon = nil,
      linehl = nil,
      text = '┃',
    },
    GitSignsDelete = {
      texthl = 'GitSignsDelete',
      numhl = nil,
      icon = nil,
      linehl = nil,
      text = '┃',
    },
    GitSignsChange = {
      texthl = 'GitSignsChange',
      numhl = nil,
      icon = nil,
      linehl = nil,
      text = '┃',
    },
  },
  usage = {
    scene = {
      add = 'GitSignsAddLn',
      remove = 'GitSignsDeleteLn',
      conflict_current_mark = 'GitConflictCurrentMark',
      conflict_current = 'GitConflictCurrent',
      conflict_middle = 'GitConflictMiddle',
      conflict_incoming_mark = 'GitConflictIncomingMark',
      conflict_incoming = 'GitConflictIncoming',
      conflict_ancestor_mark = 'GitConflictAncestorMark',
      conflict_ancestor = 'GitConflictAncestor'
    },
    main = {
      add = 'GitSignsAdd',
      remove = 'GitSignsDelete',
      change = 'GitSignsChange',
    },
  },
})
