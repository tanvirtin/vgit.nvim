local Object = require('vgit.core.Object')

local Scene = Object:extend()

function Scene:constructor()
  return {
    length = 0,
    components = {},
    component_order = {},
    default_global_opts = {},
  }
end

function Scene:get_components()
  local ordered_components = {}

  for key, component in pairs(self.components) do
    local order = self.component_order[key]
    ordered_components[order] = component
  end

  return ordered_components
end

function Scene:set(key, component)
  self.length = self.length + 1
  self.components[key] = component
  self.component_order[key] = self.length

  return self
end

function Scene:get(key)
  return self.components[key]
end

function Scene:is_focused()
  local focused = false

  for _, component in pairs(self.components) do
    if component:is_focused() then return true end
  end

  return focused
end

function Scene:on(event_name, callback)
  for _, component in pairs(self.components) do
    component:on(event_name, callback)
  end

  return self
end

function Scene:destroy()
  local components = self:get_components()

  for _, component in pairs(components) do
    component:unmount()
  end

  return self
end

return Scene
