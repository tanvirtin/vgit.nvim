local Component = require('vgit.ui.Component')

local LayoutComponent = Component:extend()

function LayoutComponent:render() end

function LayoutComponent:component_did_mount() self:render() end

function LayoutComponent:get_layout_spec()
  return self.props.spec
end

return LayoutComponent
