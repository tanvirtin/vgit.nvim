local lazy = require('vgit.core.lazy')

local Component = lazy('vgit.ui.Component')
local LayoutSpec = lazy('vgit.ui.layout.LayoutSpec')

local CompositeComponent = Component:extend()

function CompositeComponent:constructor(props)
  local instance = Component.constructor(self, props)

  instance.children = {}

  return instance
end

function CompositeComponent:get_child_classes()
  return {}
end

function CompositeComponent:mount()
  if self._mounted then return end

  for name, ChildClass in pairs(self:get_child_classes()) do
    if not self.children[name] then self.children[name] = ChildClass({}) end
  end

  self._mounted = true
end

function CompositeComponent:unmount()
  if not self._mounted then return end

  self:on_unmount()

  for _, child in pairs(self.children) do
    if child.unmount then child:unmount() end
  end

  self.children = {}
  self._mounted = false
end

function CompositeComponent:get_layout_spec()
  return self:layout(LayoutSpec)
end

return CompositeComponent
