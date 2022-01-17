local Config = require('vgit.core.Config')

return Config:new({
  GitBackgroundPrimary = 'Normal',
  GitBackgroundSecondary = 'StatusLine',
  GitBorder = 'LineNr',
  GitLineNr = 'LineNr',
  GitComment = 'Comment',
  GitSignsAdd = {
    gui = nil,
    fg = '#d7ffaf',
    bg = nil,
    sp = nil,
    override = false,
  },
  GitSignsChange = {
    gui = nil,
    fg = '#7AA6DA',
    bg = nil,
    sp = nil,
    override = false,
  },
  GitSignsDelete = {
    gui = nil,
    fg = '#e95678',
    bg = nil,
    sp = nil,
    override = false,
  },
  GitSignsAddLn = 'DiffAdd',
  GitSignsDeleteLn = 'DiffDelete',
  GitWordAdd = {
    gui = nil,
    fg = nil,
    bg = '#5d7a22',
    sp = nil,
    override = false,
  },
  GitWordDelete = {
    gui = nil,
    fg = nil,
    bg = '#960f3d',
    sp = nil,
    override = false,
  },
})
