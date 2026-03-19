local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local BlameContentComponent = Component({
  win_options = {
    winhl = 'Normal:GitBackground',
    signcolumn = 'no',
    wrap = false,
    number = true,
    cursorline = true,
  },
  layout_opts = { flex = 1, focus = true },
})

return BlameContentComponent
