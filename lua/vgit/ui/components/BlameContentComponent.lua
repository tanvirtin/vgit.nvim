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

  on_props = function(self, prev_props)
    if self.props.lines ~= prev_props.lines or self.props.filetype ~= prev_props.filetype then self:render() end
  end,
})

function BlameContentComponent:render()
  self:with_element(function(el)
    local lines = self.props.lines
    if lines then el:set_lines(lines) end
    if self.props.filetype then el:set_filetype(self.props.filetype) end
  end)
end

return BlameContentComponent
