local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')

local LayoutComponent = Component({})

function LayoutComponent:get_layout_spec()
  return self.props.spec
end

return LayoutComponent
