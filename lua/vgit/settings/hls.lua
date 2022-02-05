local Color = require('vgit.core.Color')
local Config = require('vgit.core.Config')

return Config({
  GitCount = 'Keyword',
  GitSymbol = 'CursorLineNr',
  GitTitle = 'Directory',
  GitBackground = function()
    return {
      bg = Color({ name = 'Normal', attribute = 'bg' }):darken(8):get(),
      fg = Color({ name = 'Normal', attribute = 'fg' }):get(),
      override = false,
    }
  end,
  GitHeader = function()
    return {
      bg = Color({ name = 'StatusLine', attribute = 'bg' }):darken(35):get(),
      fg = Color({ name = 'StatusLine', attribute = 'fg' }):get(),
      override = false,
    }
  end,
  GitFooter = function()
    return {
      bg = Color({ name = 'StatusLine', attribute = 'bg' }):darken(35):get(),
      fg = Color({ name = 'StatusLine', attribute = 'fg' }):get(),
      override = false,
    }
  end,
  GitBorder = function()
    return {
      bg = Color({ name = 'LineNr', attribute = 'bg' }):darken(5):get(),
      fg = Color({ name = 'LineNr', attribute = 'fg' }):darken(5):get(),
      override = false,
    }
  end,
  GitLineNr = function()
    return {
      bg = Color({ name = 'LineNr', attribute = 'bg' }):darken(8):get(),
      fg = Color({ name = 'LineNr', attribute = 'fg' }):darken(8):get(),
      override = false,
    }
  end,
  GitComment = function()
    return {
      bg = Color({ name = 'Comment', attribute = 'bg' }):get(),
      fg = Color({ name = 'Comment', attribute = 'fg' }):get(),
      override = false,
    }
  end,
  GitSignsAdd = function()
    return {
      fg = Color({ name = 'DiffAdd', attribute = 'bg' }):lighten(200):get(),
      override = false,
    }
  end,
  GitSignsChange = {
    fg = '#7AA6DA',
    override = false,
  },
  GitSignsDelete = function()
    return {
      fg = Color({ name = 'DiffDelete', attribute = 'bg' }):lighten(200):get(),
      override = false,
    }
  end,
  GitSignsAddLn = 'DiffAdd',
  GitSignsDeleteLn = 'DiffDelete',
  GitWordAdd = function()
    return {
      bg = Color({ name = 'DiffAdd', attribute = 'bg' }):lighten(50):get(),
      override = false,
    }
  end,
  GitWordDelete = function()
    return {
      bg = Color({ name = 'DiffDelete', attribute = 'bg' }):lighten(50):get(),
      override = false,
    }
  end,
})
