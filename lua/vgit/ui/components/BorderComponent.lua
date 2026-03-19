local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local BorderComponent = Component({
  win_options = function(props)
    return {
      winhl = props.winhl or 'Normal:VGitBorder',
      cursorline = false,
      cursorcolumn = false,
    }
  end,
  win_plot = { focusable = false },
  layout_opts = { height = 1 },
})

return BorderComponent
