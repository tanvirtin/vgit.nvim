local Component = require('vgit.ui.Component')

local LayoutComponent = Component:extend()

function LayoutComponent:render()
  return self.props.spec
end

return LayoutComponent
