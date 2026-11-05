local lazy = require('vgit.core.lazy')

local ElementComponent = lazy('vgit.ui.ElementComponent')

local BlameContentComponent = ElementComponent:extend()

function BlameContentComponent:get_win_options()
  return {
    winhl = 'Normal:GitBackground',
    signcolumn = 'no',
    wrap = false,
    number = true,
    cursorline = true,
  }
end

function BlameContentComponent:get_layout_opts()
  return { flex = 1, focus = true }
end

function BlameContentComponent:on_props(prev_props)
  if self.props.lines ~= prev_props.lines or self.props.filetype ~= prev_props.filetype then self:render() end
end

function BlameContentComponent:render()
  self:with_element(function(el)
    local lines = self.props.lines
    if lines then el:set_lines(lines) end
    if self.props.filetype then el:set_filetype(self.props.filetype) end
  end)
end

return BlameContentComponent
