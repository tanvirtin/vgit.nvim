local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local BlameGutterComponent = Component({
  win_options = {
    winhl = 'Normal:GitBackground',
    signcolumn = 'no',
    wrap = false,
    number = false,
    cursorline = true,
  },
  win_plot = { focusable = false },
  layout_opts = { width = '35%' },
})

function BlameGutterComponent:get_layout_spec()
  local LayoutSpec = require('vgit.ui.layout.LayoutSpec')
  return LayoutSpec.view(self._element, {
    width = self.props.width or '35%',
  })
end

return BlameGutterComponent
