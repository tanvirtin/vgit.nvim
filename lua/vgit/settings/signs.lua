local Config = require('vgit.core.Config')

return Config:new({
  priority = 10,
  definitions = {
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
    },
    main = {
      add = 'GitSignsAdd',
      remove = 'GitSignsDelete',
      change = 'GitSignsChange',
    },
  },
})
