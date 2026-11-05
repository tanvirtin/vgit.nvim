local lazy = require('vgit.core.lazy')

local ElementComponent = lazy('vgit.ui.ElementComponent')

local BorderComponent = ElementComponent:extend()

function BorderComponent:get_win_options()
  return {
    winhl = self.props.winhl or 'Normal:VGitBorder',
    cursorline = false,
    cursorcolumn = false,
  }
end

function BorderComponent:get_win_plot()
  return { focusable = false }
end

function BorderComponent:get_layout_opts()
  return { height = 1 }
end

return BorderComponent
